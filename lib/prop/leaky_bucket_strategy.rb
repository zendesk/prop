# frozen_string_literal: true
require 'prop/options'
require 'prop/key'

module Prop
  class LeakyBucketStrategy
    class << self
      def throttle(handle, key = nil, options = {})
        require 'byebug'; byebug
        options, cache_key, strategy = prepare(handle, key, options)
        throttled = _throttle(strategy, handle, key, cache_key, options).first
        block_given? && !throttled ? yield : throttled
      end

      def throttle!(handle, key = nil, options = {}, &block)
        require 'byebug'; byebug
        options, cache_key, strategy = prepare(handle, key, options)
        throttled, counter = _throttle(strategy, handle, key, cache_key, options)

        if throttled
          raise Prop::RateLimited.new(options.merge(
              cache_key: cache_key,
              handle: handle,
              first_throttled: (throttled == :first_throttled)
          ))
        end

        block_given? ? yield : counter
      end

      def counter(cache_key, options)
        bucket = Prop::Limiter.cache.read(cache_key) || zero_counter
        bucket
      end

      def update_bucket(cache_key, options)
        bucket = counter(cache_key, options)
        # now = Time.now.to_i
        now = Time.now
        leak_rate = (now.to_f - bucket.fetch(:last_updated).to_f) / options.fetch(:interval).to_f
        leak_amount =  leak_rate * options.fetch(:threshold).to_f
        bucket_floating = [(bucket.fetch(:bucket).to_f - leak_amount), 0].max
        bucket_int =  [bucket_floating.to_i, 0].max
        puts("#########################")
        puts("Prop::LeakyBucketStrategy.update_bucket #{bucket}")
        puts("##    now: #{now}")
        puts("##    leak_rate: #{leak_rate}, leak_amount: #{leak_amount}")
        puts("##    before: #{bucket[:bucket]}, #{Time.at(bucket[:last_updated])}")
        puts("##    bucket_floating: #{bucket_floating}")
        # bucket[:bucket] = [(bucket.fetch(:bucket) - leak_amount).to_i, 0].max
        bucket[:bucket] = [bucket_floating, 0].max
        bucket[:last_updated] = now.to_f
        puts("##    after: #{bucket[:bucket]}, #{Time.at(bucket[:last_updated])}")
        puts("#########################")
        bucket
      end

      # def leak_and_increment_bucket_float(cache_key, amount, options)
      #   bucket = counter(cache_key, options)
      #
      #   # leak the bucket
      #   now = Time.now
      #   leak_rate = (now.to_f - bucket.fetch(:last_updated).to_f) / options.fetch(:interval).to_f
      #   leak_amount =  leak_rate * options.fetch(:threshold).to_f
      #   bucket_floating = [(bucket.fetch(:bucket).to_f - leak_amount), 0].max
      #   bucket_int =  [bucket_floating.to_i, 0].max
      #   puts("#########################")
      #   puts("Prop::LeakyBucketStrategy.leak_and_increment_bucket #{bucket}")
      #   puts("##    now: #{now}")
      #   puts("##    leak rate: #{leak_rate}, amount: #{leak_amount}")
      #   puts("##    before: #{bucket[:bucket]}, #{Time.at(bucket[:last_updated])}")
      #   puts("##    bucket_floating: #{bucket_floating}")
      #
      #   # now increment bucket
      #   updated_bucket = bucket_floating + amount
      #   # compare to bucket_size (:burst_rate)
      #   max_bucket_size = (options.fetch(:burst_rate)-amount).to_f
      #   bucket_overflowed = false
      #   if updated_bucket > max_bucket_size
      #     puts("##    TOO BIG: old: #{bucket[:bucket]}  new: #{bucket_floating}")
      #     bucket[:bucket] = bucket_floating
      #     bucket_overflowed = true
      #   else
      #     bucket[:bucket] = updated_bucket
      #   end
      #   bucket[:bucket_overflowed] = bucket_overflowed
      #   bucket[:last_updated] = now.to_f
      #   cache_value = cache.write(cache_key, bucket)
      #   puts("##    after: #{bucket[:bucket]}, overflow: #{bucket[:bucket_overflowed]} time: #{Time.at(bucket[:last_updated])}")
      #   puts("#########################")
      #   bucket
      # end

      def leak_and_increment_bucket(cache_key, amount, options)
        bucket = counter(cache_key, options)

        # leak the bucket
        now = Time.now
        max_bucket_size = options.fetch(:burst_rate)
        current_bucket_size = bucket.fetch(:bucket)
        leak_rate = (now.to_f - bucket.fetch(:last_updated).to_f) / options.fetch(:interval).to_f
        leak_amount =  (leak_rate * options.fetch(:threshold).to_f).to_i
        puts("#########################")
        puts("Prop::LeakyBucketStrategy.leak_and_increment_bucket #{bucket}")
        puts("##    now: #{now}")
        puts("##    amount: #{amount}")
        puts("##    max_bucket_size: #{max_bucket_size}")
        puts("##    leak_rate: #{leak_rate}")
        puts("##    leak_amount: #{leak_amount}")
        puts("##    last_updated: #{Time.at(bucket[:last_updated])}")
        puts("##    current_bucket_size: #{current_bucket_size}")
        # now increment bucket
        if leak_amount >= amount
          # updated_bucket = [(current_bucket_size - leak_amount), 0].max
          # only increase the bucket size if not full
          # if we always increase the bucket size we can get into a situation where it will never have
          # a chance to empty if the api is being slammed
          if current_bucket_size < max_bucket_size
            updated_bucket = [(current_bucket_size - leak_amount), 0].max + amount

            puts("##    AAAAAAAAAAAAA: #{updated_bucket}")
          else
            # we only get here
            updated_bucket = [(current_bucket_size - leak_amount), 0].max
            puts("##    BBBBBBBBBBBBB: #{updated_bucket}")
          end
          # pin size of bucket to max_bucket_size
          updated_bucket = [updated_bucket.to_i, max_bucket_size.to_i].min
          bucket[:bucket] = updated_bucket
          bucket[:last_updated] = now
          cache_value = cache.write(cache_key, bucket)
          puts("##    AFTER updated_bucket_size: #{bucket[:bucket]}, time: #{Time.at(bucket[:last_updated])}")
        else
          updated_bucket = current_bucket_size + amount
          updated_bucket = [updated_bucket.to_i, max_bucket_size.to_i].min
          bucket[:bucket] = updated_bucket
          cache_value = cache.write(cache_key, bucket)
          puts("##    AFTER (NO UPDATE) updated_bucket_size: #{bucket[:bucket]}, time: #{Time.at(bucket[:last_updated])}")
        end
        puts("#########################")
        bucket
      end

      # # WARNING: race condition
      # # this increment is not atomic, so it might miss counts when used frequently
      # def increment(counter, cache_key, amount, options)
      #   # counter = update_bucket(cache_key, options)
      #   burst_rate = options.fetch(:burst_rate)
      #   # foo = cache.read(cache_key)
      #   # require 'byebug'; byebug
      #   puts("#########################")
      #   puts("## Prop::LeakyBucketStrategy.increment #{cache_key},  #{amount}, options: #{options}")
      #   # puts("##    before cache counter: #{foo[:bucket]}, #{Time.at(foo[:last_updated])}")
      #   puts("##    burst_rate: #{burst_rate} bucket > burst_rate => #{counter[:bucket] > burst_rate}")
      #   puts("##    before increment counter: #{counter[:bucket]}, #{Time.at(counter[:last_updated])}")
      #   counter[:bucket] += amount
      #   counter[:bucket] = [burst_rate, counter[:bucket]].min
      #
      #   # counter[:bucket] = [counter[:bucket]+amount, burst_rate+0.1].min
      #   cache_value = cache.write(cache_key, counter)
      #   # foo = cache.read(cache_key)
      #   # puts("##    after cache counter: #{foo[:bucket]}, #{Time.at(foo[:last_updated])}")
      #   puts("##    after increment counter: #{counter[:bucket]}, #{Time.at(counter[:last_updated])}")
      #   # puts("##    cache_value: #{cache_value}")
      #   # puts("##    cache_value&[:bucket]: #{cache_value&[:bucket]}")
      #   puts("#########################")
      #   counter
      # end

      def decrement(counter, cache_key, amount, options)
        bucket = counter(cache_key, options)
        bucket[:bucket] = [bucket[:bucket] - amount, 0].max
        cache.write(cache_key, bucket)
        # foo = cache.read(cache_key)
        # puts("#########################")
        # puts("Prop::LeakyBucketStrategy.decrement #{cache_key},  #{amount}, #{options} bucket: #{counter[:bucket]}, counter: #{counter} ")
        # puts("##    after cache reaad: #{foo[:bucket]}, #{Time.at(foo[:last_updated])}")
        # puts("#########################")
        bucket
      end

      def reset(cache_key)
        puts("#########################")
        puts("Prop::LeakyBucketStrategy.reset #{cache_key} ")
        puts("#########################")
        cache.write(cache_key, zero_counter)
      end

      def compare_threshold_old?(bucket, operator, options)
        over_limit = bucket[:bucket_overflowed]
        # operator = :>=
        # over_limit = counter.fetch(:bucket).to_f.send operator, options.fetch(:burst_rate).to_f
        puts("#########################")
        puts("Prop::LeakyBucketStrategy.compare_threshold? operator: #{operator}")
        puts("     over_limit: #{over_limit}")
        puts("     bucket: #{bucket.fetch(:bucket).to_f} burst_rate: #{bucket.fetch(:burst_rate).to_f}")
        puts("#########################")
        over_limit
      end

      def compare_threshold?(bucket, operator, options)
        operator = :>=
        over_limit = bucket.fetch(:bucket).send operator, options.fetch(:burst_rate)
        puts("#########################")
        puts("Prop::LeakyBucketStrategy.compare_threshold? operator: #{operator}")
        puts("     over_limit: #{over_limit}")
        puts("     bucket: #{bucket.fetch(:bucket)} burst_rate: #{options.fetch(:burst_rate)}")
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

        bucket = Prop::Limiter.cache.read(cache_key) || zero_counter
        # counter[:bucket] = burst_rate - 0.9
        # cache.write(cache_key, counter)

        puts("#########################")
        puts("Prop::LeakyBucketStrategy.threshold_reached #{options} ")
        puts("    cache_key: #{cache_key} ")
        puts("    bucket: #{bucket} ")
        puts("    counter[:bucket]: #{bucket[:bucket]} ")
        # puts("    calling decrement ")
        puts("#########################")
        # decrement(cache_key, 1, options)

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
        require 'byebug'; byebug
        { bucket: 0, last_updated: 0 }
      end

      def cache
        Prop::Limiter.cache
      end

      # private

      def _throttle(strategy, handle, key, cache_key, options)
        # return [false, strategy.zero_counter] if disabled?

        # leak the bucket happens here
        #
        #
        # bucket = update_bucket(cache_key, options)
        bucket = options.key?(:decrement) ?
          decrement(bucket, cache_key, options.fetch(:decrement), options) :
          leak_and_increment_bucket(cache_key, options.fetch(:increment, 1), options)
        # bucket = leak_and_increment_bucket(cache_key, options.fetch(:increment, 1), options)
        over_limit = if compare_threshold?(bucket, :>=, options)
          [true, bucket]
        else
          [false, bucket]
        end
        puts("#########################")
        puts("Prop::LeakyBucketStrategy._throttle")
        puts("    over_limit: #{over_limit[0]} ")
        puts("#########################")
        over_limit
      end
    end
  end
end
