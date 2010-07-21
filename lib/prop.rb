require 'digest/md5'

class Object
  def define_prop_class_method(name, &blk)
    (class << self; self; end).instance_eval { define_method(name, &blk) }
  end
end

class Prop
  class RateLimitExceededError < RuntimeError
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
        key  = handle.to_s
        key << "/#{args.first}" if args.first

        options = { :key => key, :threshold => defaults[:threshold].to_i, :interval => defaults[:interval].to_i }
        options = options.merge(args.last) if args.last.is_a?(Hash)

        throttle!(options)
      end

      define_prop_class_method "reset_#{handle}" do |*args|
        key  = handle.to_s
        key << "/#{args.first}" if args.first

        options = { :key => key, :threshold => defaults[:threshold].to_i, :interval => defaults[:interval].to_i }
        options = options.merge(args.last) if args.last.is_a?(Hash)

        reset(options)
      end
    end

    def throttle!(options)
      cache_key = sanitized_prop_key(options)
      counter   = reader.call(cache_key).to_i

      if counter >= options[:threshold]
        raise Prop::RateLimitExceededError.new("#{options[:key]} threshold #{options[:threshold]} exceeded")
      else
        writer.call(cache_key, counter + 1)
      end
    end

    def reset(options)
      cache_key = sanitized_prop_key(options)
      writer.call(cache_key, 0)
    end

    private

    def sanitized_prop_key(options)
      cache_key = "#{options[:key]}/#{Time.now.to_i / options[:interval]}"
      "prop/#{Digest::MD5.hexdigest(cache_key)}"
    end
  end
end
