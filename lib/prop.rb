require 'digest/md5'

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

    def configure(handle, options)
      raise RuntimeError.new("Invalid threshold setting") unless options[:threshold].to_i > 0
      raise RuntimeError.new("Invalid interval setting") unless options[:interval].to_i > 0

      self.handles ||= {}
      self.handles[handle] = options
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

    def method_missing(handle, *arguments, &block)
      self.handles ||= {}

      if handle.to_s =~ /^reset_(.+)/ && options = handles[$1.to_sym]
        return reset(options.merge(:key => "#{$1}#{"/#{arguments.first}" if arguments.first}"))
      elsif options = handles[handle]
        return throttle!(options.merge(:key => "#{handle}#{"/#{arguments.first}" if arguments.first}"))
      end

      super
    end

    private

    def sanitized_prop_key(options)
      cache_key = "#{options[:key]}/#{Time.now.to_i / options[:interval]}"
      "prop/#{Digest::MD5.hexdigest(cache_key)}"
    end
  end
end
