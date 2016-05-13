# frozen_string_literal: true
require 'prop/key'

module Prop
  class Options

    # Sanitizes the option set and sets defaults
    def self.build(options)
      key      = options.fetch(:key)
      params   = options.fetch(:params)
      defaults = options.fetch(:defaults)
      result   = defaults.merge(params)

      result[:key] = Prop::Key.normalize(key)

      result[:strategy] = if leaky_bucket.include?(result[:strategy])
        Prop::LeakyBucketStrategy
      elsif result[:strategy] == nil
        Prop::IntervalStrategy
      else
        result[:strategy] # allowing any new/unknown strategy to be used
      end

      result[:strategy].validate_options!(result)
      result
    end

    def self.leaky_bucket
      [:leaky_bucket, "leaky_bucket"]
    end
  end
end
