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
      result[:strategy] = get_strategy(result)

      result[:strategy].validate_options!(result)
      result
    end

    def self.validate_options!(options)
      get_strategy(options).validate_options!(options)
    end

    def self.get_strategy(options)
      if leaky_bucket.include?(options[:strategy])
        Prop::LeakyBucketStrategy
      elsif options[:strategy] == nil
        Prop::IntervalStrategy
      else
        options[:strategy] # allowing any new/unknown strategy to be used
      end
    end

    def self.leaky_bucket
      [:leaky_bucket, "leaky_bucket"]
    end
  end
end
