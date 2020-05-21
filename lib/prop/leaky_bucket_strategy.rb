# frozen_string_literal: true
require 'prop/options'
require 'prop/key'

module Prop
  class LeakyBucketStrategy
    class << self
      def counter(cache_key, options)
        bucket = Prop::Limiter.cache.read(cache_key) || zero_counter
        # now = Time.now.to_i
        now = Time.now
        leak_rate = (now.to_f - bucket.fetch(:last_updated).to_f) / options.fetch(:interval).to_f
        leak_amount =  leak_rate * options.fetch(:threshold).to_f
        bucket_floating = [(bucket.fetch(:bucket).to_f - leak_amount), 0].max
        bucket_int =  [bucket_floating.to_i, 0].max
        puts("#########################")
        puts("Prop::LeakyBucketStrategy.counter #{bucket}")
        puts("##    now: #{now}")
        puts("##    leak rate: #{leak_rate}, amount: #{leak_amount}")
        puts("##    before counter: #{bucket[:bucket]}, #{Time.at(bucket[:last_updated])}")
        puts("##    bucket_floating: #{bucket_floating}")
        # bucket[:bucket] = [(bucket.fetch(:bucket) - leak_amount).to_i, 0].max
        bucket[:bucket] = [bucket_floating, 0].max
        bucket[:last_updated] = now.to_f
        puts("##    after counter: #{bucket[:bucket]}, #{Time.at(bucket[:last_updated])}")
        puts("#########################")
        bucket
      end

      # WARNING: race condition
      # this increment is not atomic, so it might miss counts when used frequently
      def increment(cache_key, amount, options)
        counter = counter(cache_key, options)
        burst_rate = options.fetch(:burst_rate)
        # foo = cache.read(cache_key)
        # require 'byebug'; byebug
        puts("#########################")
        puts("## Prop::LeakyBucketStrategy.increment #{cache_key},  #{amount}, options: #{options}")
        # puts("##    before cache counter: #{foo[:bucket]}, #{Time.at(foo[:last_updated])}")
        puts("##    burst_rate: #{burst_rate} bucket > burst_rate => #{counter[:bucket] > burst_rate}")
        puts("##    before increment counter: #{counter[:bucket]}, #{Time.at(counter[:last_updated])}")
        counter[:bucket] += amount
        # counter[:bucket] = [counter[:bucket]+amount, burst_rate+0.1].min
        cache_value = cache.write(cache_key, counter)
        # foo = cache.read(cache_key)
        # puts("##    after cache counter: #{foo[:bucket]}, #{Time.at(foo[:last_updated])}")
        puts("##    after increment counter: #{counter[:bucket]}, #{Time.at(counter[:last_updated])}")
        # puts("##    cache_value: #{cache_value}")
        # puts("##    cache_value&[:bucket]: #{cache_value&[:bucket]}")
        puts("#########################")
        counter
      end

      def decrement(cache_key, amount, options)
        counter = counter(cache_key, options)
        counter[:bucket] -= amount
        counter[:bucket] = 0 unless counter[:bucket] > 0
        cache.write(cache_key, counter)
        foo = cache.read(cache_key)
        puts("#########################")
        puts("Prop::LeakyBucketStrategy.decrement #{cache_key},  #{amount}, #{options} bucket: #{counter[:bucket]}, counter: #{counter} ")
        puts("##    after cache reaad: #{foo[:bucket]}, #{Time.at(foo[:last_updated])}")
        puts("#########################")
        counter
      end

      def reset(cache_key)
        puts("#########################")
        puts("Prop::LeakyBucketStrategy.reset #{cache_key} ")
        puts("#########################")
        cache.write(cache_key, zero_counter)
      end

      def compare_threshold?(counter, operator, options)
        over_limit = counter.fetch(:bucket).to_f.send operator, options.fetch(:burst_rate).to_f
        puts("#########################")
        puts("Prop::LeakyBucketStrategy.compare_threshold? over_limit: #{over_limit}")
        puts("     bucket: #{counter.fetch(:bucket).to_f} burst_rate: #{options.fetch(:burst_rate).to_f}")
        puts("#########################")
        over_limit
      end

      def build(options)
        key       = options.fetch(:key)
        handle    = options.fetch(:handle)

        cache_key = Prop::Key.normalize([ handle, key ])

        "prop/leaky_bucket/#{Digest::MD5.hexdigest(cache_key)}"
      end

      def threshold_reached(options)
        cache_key = build(options)

        burst_rate = options.fetch(:burst_rate)
        threshold  = options.fetch(:threshold)

        counter = Prop::Limiter.cache.read(cache_key) || zero_counter
        # counter[:bucket] = burst_rate - 0.9
        # cache.write(cache_key, counter)

        puts("#########################")
        puts("Prop::LeakyBucketStrategy.threshold_reached #{options} ")
        puts("    cache_key: #{cache_key} ")
        puts("    counter[:bucket]: #{counter[:bucket]} ")
        # puts("    calling decrement ")
        puts("#########################")
        decrement(cache_key, 1, options)

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
        puts("#########################")
        puts("Prop::LeakyBucketStrategy.zero_counter")
        puts("#########################")
        { bucket: 0, last_updated: 0 }
      end

      def cache
        Prop::Limiter.cache
      end
    end
  end
end
