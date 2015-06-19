require 'prop/key'
require 'prop/options'
require 'prop/limiter'
require 'prop/rate_limited'

module LeakyBucket
  class Bucket

    class << self
      def leaky(handle, key = nil, options = {})
        options, cache_key = prepare(handle, key, options)
        update_bucket(cache_key, options[:interval], options[:threshold])
        counter = Prop::Limiter.reader.call(cache_key).fetch(:bucket).to_i

        if bucket_full?(counter, options[:burst_rate])
          true
        else
          increment = options.key?(:increment) ? options[:increment].to_i : 1
          bucket = { :bucket => counter + increment, :last_updated => Time.now.to_i }
          Prop::Limiter.writer.call(cache_key, bucket)

          false
        end
      end

      def leaky!(handle, key = nil, options = {})
        options, cache_key = prepare(handle, key, options)

        if leaky(handle, key, options)
          raise Prop::RateLimited.new(options.merge(:cache_key => cache_key, :handle => handle))
        end

        block_given? ? yield : Prop::Limiter.reader.call(cache_key).fetch(:bucket).to_i
      end

      def update_bucket(cache_key, interval, leak_rate)
        bucket = Prop::Limiter.reader.call(cache_key) || { :bucket => 0, :last_updated => 0 }
        current = Time.now.to_i
        leak_amount = (current - bucket[:last_updated]) / interval * leak_rate

        bucket[:bucket] = [bucket[:bucket] - leak_amount, 0].max
        bucket[:last_updated] = current

        Prop::Limiter.writer.call(cache_key, bucket)
      end

      def reset_bucket(handle, key = nil, options = {})
        options, cache_key = prepare(handle, key, options)
        Prop::Limiter.writer.call(cache_key, { :bucket => 0, :last_updated => Time.now.to_i })
      end

      private

      def prepare(handle, key, params)
        raise RuntimeError.new("No such handle configured: #{handle.inspect}") unless (Prop::Limiter.handles || {}).key?(handle)

        defaults  = Prop::Limiter.handles[handle]
        options   = Prop::Options.build(:key => key, :params => params, :defaults => defaults)
        cache_key = Prop::Key.build_bucket_key(:key => key, :handle => handle)

        options[:burst_rate] = options.fetch(:burst_rate).to_i
        raise RuntimeError.new("Invalid burst rate setting") unless options[:burst_rate] > options[:threshold]

        [options, cache_key]
      end

      def bucket_full?(counter, burst_rate)
        counter >= burst_rate
      end
    end
  end
end
