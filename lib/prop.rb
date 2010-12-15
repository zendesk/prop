require 'digest/md5'

class Object
  def define_prop_class_method(name, &blk)
    (class << self; self; end).instance_eval { define_method(name, &blk) }
  end
end

class Prop
  class RateLimitExceededError < RuntimeError
    attr_accessor :handle, :retry_after

    def self.create(handle, key, threshold)
      error = new("#{handle} threshold of #{threshold} exceeded for key '#{key}'")
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

    def defaults(handle, defaults)
      raise RuntimeError.new("Invalid threshold setting") unless defaults[:threshold].to_i > 0
      raise RuntimeError.new("Invalid interval setting")  unless defaults[:interval].to_i > 0

      self.handles ||= {}
      self.handles[handle] = defaults
    end

    def throttle!(handle, key = nil, options = {})
      options   = sanitized_prop_options(handle, key, options)
      cache_key = sanitized_prop_key(key, options[:interval])
      counter   = reader.call(cache_key).to_i

      if counter >= options[:threshold]
        raise Prop::RateLimitExceededError.create(handle, normalize_cache_key(key), options[:threshold])
      else
        writer.call(cache_key, counter + [ 1, options[:increment].to_i ].max)
      end
    end

    def throttled?(handle, key = nil, options = {})
      options   = sanitized_prop_options(handle, key, options)
      cache_key = sanitized_prop_key(key, options[:interval])

      reader.call(cache_key).to_i >= options[:threshold]
    end

    def reset(handle, key = nil, options = {})
      options   = sanitized_prop_options(handle, key, options)
      cache_key = sanitized_prop_key(key, options[:interval])

      writer.call(cache_key, 0)
    end

    def query(handle, key = nil, options = {})
      options   = sanitized_prop_options(handle, key, options)
      cache_key = sanitized_prop_key(key, options[:interval])

      reader.call(cache_key).to_i
    end

    private

    # Builds the expiring cache key
    def sanitized_prop_key(key, interval)
      window    = (Time.now.to_i / interval)
      cache_key = "#{normalize_cache_key(key)}/#{ window }"
      "prop/#{Digest::MD5.hexdigest(cache_key)}"
    end

    # Sanitizes the option set and sets defaults
    def sanitized_prop_options(handle, key, options)
      defaults = (handles || {})[handle] || {}
      return {
        :key       => normalize_cache_key(key),
        :increment => defaults[:increment],
        :threshold => defaults[:threshold].to_i,
        :interval  => defaults[:interval].to_i
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
