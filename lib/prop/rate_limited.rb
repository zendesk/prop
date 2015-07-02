module Prop
  class RateLimited < StandardError
    attr_accessor :handle, :cache_key, :retry_after, :description

    def initialize(options)
      handle    = options.fetch(:handle)
      cache_key = options.fetch(:cache_key)
      interval  = options.fetch(:interval).to_i
      threshold = options.fetch(:threshold).to_i

      if burst_rate = options[:burst_rate]
        super("#{handle} threshold of #{threshold} tries per #{interval}s and burst rate #{burst_rate} tries exceeded for key '#{options[:key].inspect}', hash #{cache_key}")
      else
        super("#{handle} threshold of #{threshold} tries per #{interval}s exceeded for key '#{options[:key].inspect}', hash #{cache_key}")
      end

      self.description = options[:description]
      self.handle      = handle
      self.cache_key   = cache_key
      self.retry_after = interval - Time.now.to_i % interval
    end

    def config
      Prop.configurations[@handle]
    end
  end
end
