require 'digest/md5'

class Object
  def define_prop_class_method(name, &blk)
    (class << self; self; end).instance_eval { define_method(name, &blk) }
  end
end

class Prop
  class RateLimitExceededError < RuntimeError
    attr_reader :root_message, :retry_after

    def initialize(key, threshold, message)
      @root_message = "#{key} threshold #{threshold} exceeded"
      @retry_after  = Time.now.to_i % threshold.to_i

      super(message || @root_message)
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

    def setup(handle, defaults)
      raise RuntimeError.new("Invalid threshold setting") unless defaults[:threshold].to_i > 0
      raise RuntimeError.new("Invalid interval setting") unless defaults[:interval].to_i > 0

      define_prop_class_method "throttle_#{handle}!" do |*args|
        throttle!(sanitized_prop_options([ handle ] + args, defaults))
      end

      define_prop_class_method "throttle_#{handle}?" do |*args|
        throttle?(sanitized_prop_options([ handle ] + args, defaults))
      end

      define_prop_class_method "reset_#{handle}" do |*args|
        reset(sanitized_prop_options([ handle ] + args, defaults))
      end
    end

    def throttle?(options)
      count(options) >= options[:threshold]
    end

    def throttle!(options)
      counter = count(options)

      if counter >= options[:threshold]
        raise Prop::RateLimitExceededError.new(options[:key], options[:threshold], options[:message])
      else
        writer.call(sanitized_prop_key(options), counter + 1)
      end
    end

    def reset(options)
      cache_key = sanitized_prop_key(options)
      writer.call(cache_key, 0)
    end

    def count(options)
      cache_key = sanitized_prop_key(options)
      reader.call(cache_key).to_i
    end

    private

    # Builds the expiring cache key
    def sanitized_prop_key(options)
      cache_key = "#{normalize_cache_key(options[:key])}/#{Time.now.to_i / options[:interval]}"
      "prop/#{Digest::MD5.hexdigest(cache_key)}"
    end

    # Sanitizes the option set and sets defaults
    def sanitized_prop_options(args, defaults)
      options = args.last.is_a?(Hash) ? args.pop : {}
      return {
        :key => normalize_cache_key(args), :message => defaults[:message],
        :threshold => defaults[:threshold].to_i, :interval => defaults[:interval].to_i
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
