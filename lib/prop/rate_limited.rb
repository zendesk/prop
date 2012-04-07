module Prop
  class RateLimited < StandardError
    attr_accessor :handle, :cache_key, :retry_after, :description

    def initialize(options)
      handle    = options.fetch(:handle)
      cache_key = options.fetch(:cache_key)
      interval  = options.fetch(:interval).to_i
      threshold = options.fetch(:threshold).to_i

      super("#{handle} threshold of #{threshold}/#{interval}s exceeded for key '#{cache_key}'")

      self.description = options[:description]
      self.handle      = handle
      self.cache_key   = cache_key
      self.retry_after = interval - Time.now.to_i % interval
    end
  end
end