require 'prop/limiter'
require 'prop/options'
require 'prop/key'
require 'prop/interval_strategy'

module Prop
  class LeakyBucketStrategy
    class << self
      def counter(cache_key, options)
        bucket = Prop::Limiter.cache.read(cache_key) || zero_counter
        now = Time.now.to_i
        leak_amount = (now - bucket.fetch(:last_updated)) / options.fetch(:interval) * options.fetch(:threshold)

        bucket[:bucket] = [bucket.fetch(:bucket) - leak_amount, 0].max
        bucket[:last_updated] = now
        bucket
      end

      # WARNING: race condition
      # this increment is not atomic, so it might miss counts when used frequently
      def increment(cache_key, options)
        counter = counter(cache_key, options)
        counter[:bucket] += options.fetch(:increment, 1)
        Prop::Limiter.cache.write(cache_key, counter)
        counter
      end

      def reset(cache_key)
        Prop::Limiter.cache.write(cache_key, zero_counter)
      end

      def compare_threshold?(counter, operator, options)
        counter.fetch(:bucket).to_i.send operator, options.fetch(:burst_rate)
      end

      def build(options)
        key       = options.fetch(:key)
        handle    = options.fetch(:handle)

        cache_key = Prop::Key.normalize([ handle, key ])

        "prop/leaky_bucket/#{Digest::MD5.hexdigest(cache_key)}"
      end

      def threshold_reached(options)
        burst_rate = options.fetch(:burst_rate)
        threshold  = options.fetch(:threshold)

        "#{options[:handle]} threshold of #{threshold} tries per #{options[:interval]}s and burst rate #{burst_rate} tries exceeded for key #{options[:key].inspect}, hash #{options[:cache_key]}"
      end

      def validate_options!(options)
        Prop::IntervalStrategy.validate_options!(options)

        if !options[:burst_rate].is_a?(Fixnum) || options[:burst_rate] < options[:threshold]
          raise ArgumentError.new(":burst_rate must be an Integer and not less than :threshold")
        end

        if options[:first_throttled]
          raise ArgumentError.new(":first_throttled is not supported")
        end
      end

      def zero_counter
        { bucket: 0, last_updated: 0 }
      end
    end
  end
end
