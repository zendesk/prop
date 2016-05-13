# frozen_string_literal: true
module Prop
  class RateLimited < StandardError
    attr_accessor :handle, :cache_key, :retry_after, :description, :first_throttled

    def initialize(options)
      self.handle    = options.fetch(:handle)
      self.cache_key = options.fetch(:cache_key)
      self.first_throttled = options.fetch(:first_throttled)
      self.description = options[:description]

      interval  = options.fetch(:interval).to_i
      self.retry_after = interval - Time.now.to_i % interval

      super(options.fetch(:strategy).threshold_reached(options))
    end

    def config
      Prop.configurations.fetch(@handle)
    end
  end
end
