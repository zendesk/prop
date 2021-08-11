# frozen_string_literal: true
require 'prop/options'
require 'prop/key'

module Prop
  class LeakyBucketStrategy
    class << self
      def _throttle_leaky_bucket(handle, key, cache_key, options)
        (over_limit, bucket) = options.key?(:decrement) ?
          decrement(cache_key, options.fetch(:decrement), options) :
          increment(cache_key, options.fetch(:increment, 1), options)

        [over_limit, bucket]
      end

      def counter(cache_key, options)
        cache.read(cache_key) || zero_counter
      end

      def leak_amount(bucket, amount, options, now)
        leak_rate = (now - bucket.fetch(:last_leak_time, 0)) / options.fetch(:interval).to_f
        leak_amount = (leak_rate * options.fetch(:threshold).to_f)
        leak_amount.to_i
      end

      def update_bucket(current_bucket_size, max_bucket_size, amount)
        over_limit = (max_bucket_size-current_bucket_size) < amount
        updated_bucket_size = over_limit ? current_bucket_size : current_bucket_size + amount
        [over_limit, updated_bucket_size]
      end

      # WARNING: race condition
      # this increment is not atomic, so it might miss counts when used frequently
      def increment(cache_key, amount, options)
        bucket = counter(cache_key, options)
        now = Time.now.to_i
        max_bucket_size = options.fetch(:burst_rate)
        current_bucket_size = bucket.fetch(:bucket, 0)
        leak_amount = leak_amount(bucket, amount, options, now)
        if leak_amount > 0
          # maybe TODO, update last_leak_time to reflect the exact time for the current leak amount
          # the current strategy will always reflect a little less leakage, probably not an issue though
          bucket[:last_leak_time] = now
          current_bucket_size = [(current_bucket_size - leak_amount), 0].max
        end

        over_limit, updated_bucket_size = update_bucket(current_bucket_size, max_bucket_size, amount)
        bucket[:bucket] = updated_bucket_size
        bucket[:over_limit] = over_limit
        cache.write(cache_key, bucket)
        [over_limit, bucket]
      end

      def decrement(cache_key, amount, options)
        now = Time.now.to_i
        bucket = counter(cache_key, options)
        leak_amount = leak_amount(bucket, amount, options, now)
        bucket[:bucket] = [bucket[:bucket] - amount - leak_amount, 0].max
        bucket[:last_leak_time] = now if leak_amount > 0
        bucket[:over_limit] = false
        cache.write(cache_key, bucket)
        [false, bucket]
      end

      def reset(cache_key, options = {})
        cache.write(cache_key, zero_counter, raw: true)
      end

      def compare_threshold?(bucket, operator, options)
        bucket.fetch(:over_limit, false)
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

        if !options[:burst_rate].is_a?(Integer) || options[:burst_rate] < options[:threshold]
          raise ArgumentError.new(":burst_rate must be an Integer and not less than :threshold")
        end

        if options[:first_throttled]
          raise ArgumentError.new(":first_throttled is not supported")
        end
      end

      def zero_counter
        { bucket: 0, last_leak_time: 0, over_limit: false }
      end

      def cache
        Prop::Limiter.cache
      end
    end
  end
end
