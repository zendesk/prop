class Prop
  class RateLimitExceededError < RuntimeError
  end

  class << self
    attr_accessor :store
    attr_accessor :handles

    def configure(handle, options)
      raise RuntimeError.new("Invalid threshold setting") unless options[:threshold].to_i > 0
      raise RuntimeError.new("Invalid interval setting") unless options[:interval].to_i > 0

      self.handles ||= {}
      self.handles[handle] = options
    end

    def throttle!(options)
      cache_key = "prop/#{options[:key]}/#{Time.now.to_i / options[:interval]}"
      counter   = store[cache_key].to_i

      if counter >= options[:threshold]
        raise Prop::RateLimitExceededError.new("#{options[:key]} threshold #{options[:threshold]} exceeded")
      else
        store[cache_key] = counter + 1
      end
    end

    def method_missing(handle, *arguments, &block)
      self.handles ||= {}
      if options = handles[handle]
        throttle!(options.merge(:key => "#{handle}/#{arguments.first}"))
      else
        super
      end
    end
  end
end
