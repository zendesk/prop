require 'digest/md5'

class Object
  def define_prop_class_method(name, &blk)
    (class << self; self; end).instance_eval { define_method(name, &blk) }
  end
end

class Prop
  VERSION = "0.6.5"

  class RateLimitExceededError < RuntimeError
    attr_accessor :handle, :retry_after, :description

    def self.create(handle, key, threshold, description = nil)
      error = new("#{handle} threshold of #{threshold} exceeded for key '#{key}'")
      error.description = description
      error.handle      = handle
      error.retry_after = threshold - Time.now.to_i % threshold if threshold > 0

      raise error
    end
  end

  class << self
    attr_accessor :handles, :reader, :writer

    def read(&blk)
      self.reader = blk
    end

    def write(&blk)
      self.writer = blk
    end

    def configure(handle, defaults)
      raise RuntimeError.new("Invalid threshold setting") unless defaults[:threshold].to_i > 0
      raise RuntimeError.new("Invalid interval setting")  unless defaults[:interval].to_i > 0

      self.handles ||= {}
      self.handles[handle] = defaults
    end

    def disabled(&block)
      @disabled = true
      yield
    ensure
      @disabled = false
    end

    def disabled?
      !!@disabled
    end

    def throttle!(handle, key = nil, options = {})
      options   = sanitized_prop_options(handle, key, options)
      cache_key = sanitized_prop_key(handle, key, options)
      counter   = reader.call(cache_key).to_i

      return counter if disabled?

      if counter >= options[:threshold]
        raise Prop::RateLimitExceededError.create(handle, normalize_cache_key(key), options[:threshold], options[:description])
      else
        writer.call(cache_key, counter + [ 1, options[:increment].to_i ].max)
      end
    end

    def throttled?(handle, key = nil, options = {})
      options   = sanitized_prop_options(handle, key, options)
      cache_key = sanitized_prop_key(handle, key, options)

      reader.call(cache_key).to_i >= options[:threshold]
    end

    def reset(handle, key = nil, options = {})
      options   = sanitized_prop_options(handle, key, options)
      cache_key = sanitized_prop_key(handle, key, options)

      writer.call(cache_key, 0)
    end

    def query(handle, key = nil, options = {})
      options   = sanitized_prop_options(handle, key, options)
      cache_key = sanitized_prop_key(handle, key, options)

      reader.call(cache_key).to_i
    end
    alias :count :query

    private

    # Builds the expiring cache key
    def sanitized_prop_key(handle, key, options)
      window    = (Time.now.to_i / options[:interval])
      cache_key = normalize_cache_key([handle, key, window])
      "prop/#{Digest::MD5.hexdigest(cache_key)}"
    end

    # Sanitizes the option set and sets defaults
    def sanitized_prop_options(handle, key, options)
      raise RuntimeError.new("No such handle configured: #{handle.inspect}") if handles.nil? || handles[handle].nil?

      defaults = handles[handle]
      return {
        :key         => normalize_cache_key(key),
        :increment   => defaults[:increment],
        :description => defaults[:description],
        :threshold   => defaults[:threshold].to_i,
        :interval    => defaults[:interval].to_i
      }.merge(options)
    end

    # Simple key expansion only supports arrays and primitives
    def normalize_cache_key(key)
      if key.is_a?(Array)
        key.map { |part| normalize_cache_key(part) }.join('/')
      else
        key.to_s
      end
    end

  end
end
