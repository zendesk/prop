require 'prop/limiter'
require 'prop/options'
require 'prop/key'

module Prop
  class IntervalStrategy
    class << self
      def counter(cache_key, options)
        Prop::Limiter.cache.read(cache_key).to_i
      end

      def increment(cache_key, options)
        increment = options.fetch(:increment, 1)
        cache = Prop::Limiter.cache
        cache.increment(cache_key, increment) || (cache.write(cache_key, increment, raw: true) && increment) # WARNING: potential race condition
      end

      def reset(cache_key)
        Prop::Limiter.cache.write(cache_key, 0)
      end

      def compare_threshold?(counter, operator, options)
        counter.send operator, options.fetch(:threshold)
      end

      # Builds the expiring cache key
      def build(options)
        key       = options.fetch(:key)
        handle    = options.fetch(:handle)
        interval  = options.fetch(:interval)

        window    = (Time.now.to_i / interval)
        cache_key = Prop::Key.normalize([ handle, key, window ])

        "prop/v2/#{Digest::MD5.hexdigest(cache_key)}"
      end

      def threshold_reached(options)
        threshold = options.fetch(:threshold)

        "#{options[:handle]} threshold of #{threshold} tries per #{options[:interval]}s exceeded for key #{options[:key].inspect}, hash #{options[:cache_key]}"
      end

      def validate_options!(options)
        validate_positive_integer(options[:threshold], :threshold)
        validate_positive_integer(options[:interval], :interval)

        if options.key?(:increment)
          raise ArgumentError.new(":increment must be zero or a positive Integer") if !options[:increment].is_a?(Fixnum) || options[:increment] < 0
        end
      end

      private

      def validate_positive_integer(option, key)
        raise ArgumentError.new("#{key.inspect} must be a positive Integer") if !option.is_a?(Fixnum) || option <= 0
      end
    end
  end
end
