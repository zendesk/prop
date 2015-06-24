require 'prop/limiter'
require 'prop/key'

module Prop
  class LeakyBucketStrategy
    DEFAULT_BUCKET = { :bucket => 0, :last_updated => 0 }

    class << self
      def update_bucket(cache_key, interval, leak_rate)
        bucket = Prop::Limiter.reader.call(cache_key) || DEFAULT_BUCKET
        now = Time.now.to_i
        leak_amount = (now - bucket[:last_updated]) / interval * leak_rate

        bucket[:bucket] = [bucket[:bucket] - leak_amount, 0].max
        bucket[:last_updated] = now

        Prop::Limiter.writer.call(cache_key, bucket)
      end

      def counter(cache_key, options)
        update_bucket(cache_key, options[:interval], options[:threshold])
      end

      def increment(cache_key, options, counter)
        increment = options.key?(:increment) ? options[:increment] : 1
        bucket = { :bucket => counter[:bucket].to_i + increment, :last_updated => Time.now.to_i }
        Prop::Limiter.writer.call(cache_key, bucket)
      end

      def reset(cache_key)
        Prop::Limiter.writer.call(cache_key, DEFAULT_BUCKET)
      end

      def at_threshold?(counter, options)
        counter[:bucket].to_i >= options[:burst_rate]
      end

      def build(options)
        key       = options.fetch(:key)
        handle    = options.fetch(:handle)

        cache_key = Prop::Key.normalize([ handle, key ])

        "prop/leaky_bucket/#{Digest::MD5.hexdigest(cache_key)}"
      end
    end
  end
end
