require 'prop/limiter'
require 'prop/options'
require 'prop/key'
require 'prop/interval_strategy'

module Prop
  class LeakyBucketStrategy
    class << self
      def update_bucket(cache_key, interval, leak_rate)
        bucket = Prop::Limiter.reader.call(cache_key) || default_bucket
        now = Time.now.to_i
        leak_amount = (now - bucket[:last_updated]) / interval * leak_rate

        bucket[:bucket] = [bucket[:bucket] - leak_amount, 0].max
        bucket[:last_updated] = now

        Prop::Limiter.writer.call(cache_key, bucket)
        bucket
      end

      def counter(cache_key, options)
        update_bucket(cache_key, options[:interval], options[:threshold]).merge(burst_rate: options[:burst_rate])
      end

      def increment(cache_key, options, counter)
        increment = options.fetch(:increment, 1)
        bucket = { :bucket => counter[:bucket].to_i + increment, :last_updated => Time.now.to_i }
        Prop::Limiter.writer.call(cache_key, bucket)
      end

      def reset(cache_key)
        Prop::Limiter.writer.call(cache_key, default_bucket)
      end

      def at_threshold?(counter, options)
        counter[:bucket].to_i >= options.fetch(:burst_rate)
      end

      def build(options)
        key       = options.fetch(:key)
        handle    = options.fetch(:handle)

        cache_key = Prop::Key.normalize([ handle, key ])

        "prop/leaky_bucket/#{Digest::MD5.hexdigest(cache_key)}"
      end

      def default_bucket
        { :bucket => 0, :last_updated => 0 }
      end

      def threshold_reached(options)
        burst_rate = options.fetch(:burst_rate)
        threshold  = options.fetch(:threshold)

        "#{options[:handle]} threshold of #{threshold} tries per #{options[:interval]}s and burst rate #{burst_rate} tries exceeded for key '#{options[:key].inspect}', hash #{options[:cache_key]}"
      end

      def validate_options!(options)
        Prop::IntervalStrategy.validate_options!(options)

        if !options[:burst_rate].is_a?(Fixnum) || options[:burst_rate] < options[:threshold]
          raise ArgumentError.new(":burst_rate must be an Integer and larger than :threshold")
        end
      end
    end
  end
end
