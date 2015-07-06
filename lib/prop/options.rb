require 'prop/key'

module Prop
  class Options

    # Sanitizes the option set and sets defaults
    def self.build(options)
      key      = options.fetch(:key)
      params   = options.fetch(:params)
      defaults = options.fetch(:defaults)
      result   = defaults.merge(params)

      result[:key]       = Prop::Key.normalize(key)
      result[:threshold] = result[:threshold].to_i
      result[:interval]  = result[:interval].to_i

      raise RuntimeError.new("Invalid threshold setting") unless result[:threshold] > 0
      raise RuntimeError.new("Invalid interval setting")  unless result[:interval] > 0

      if result.key?(:increment)
        raise ArgumentError.new(":increment must be an positive Integer") if !result[:increment].is_a?(Fixnum) || result[:increment] <= 0
      end

      if leaky_bucket.include?(result[:strategy])
        result[:burst_rate] = result[:burst_rate].to_i
        if result[:burst_rate] < result[:threshold]
          raise RuntimeError.new("Invalid burst rate setting")
        end

        result[:strategy] = Prop::LeakyBucketStrategy
      else
        result[:strategy] = Prop::IntervalStrategy
      end

      result
    end

    def self.leaky_bucket
      [:leaky_bucket, "leaky_bucket", Prop::LeakyBucketStrategy]
    end
  end
end
