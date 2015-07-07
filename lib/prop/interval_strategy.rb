require 'prop/limiter'
require 'prop/options'
require 'prop/key'

module Prop
  class IntervalStrategy
    class << self
      def counter(cache_key, options)
        Prop::Limiter.reader.call(cache_key).to_i
      end

      def increment(cache_key, options, counter)
        increment = options.fetch(:increment, 1)
        Prop::Limiter.writer.call(cache_key, counter + increment)
      end

      def reset(cache_key)
        Prop::Limiter.writer.call(cache_key, 0)
      end

      def at_threshold?(counter, options)
        counter >= options.fetch(:threshold)
      end

      # Builds the expiring cache key
      def build(options)
        key       = options.fetch(:key)
        handle    = options.fetch(:handle)
        interval  = options.fetch(:interval)

        window    = (Time.now.to_i / interval)
        cache_key = Prop::Key.normalize([ handle, key, window ])

        "prop/#{Digest::MD5.hexdigest(cache_key)}"
      end

      def threshold_reached(options)
        threshold = options.fetch(:threshold)

        "#{options[:handle]} threshold of #{threshold} tries per #{options[:interval]}s exceeded for key '#{options[:key].inspect}', hash #{options[:cache_key]}"
      end

      def validate_options!(options)
        validate_positive_integer(options[:threshold], :threshold)
        validate_positive_integer(options[:interval], :interval)

        if options.key?(:increment)
          validate_positive_integer(options[:increment], :increment)
        end
      end

      private

      def validate_positive_integer(option, key)
        raise ArgumentError.new("#{key.inspect} must be an positive Integer") if !option.is_a?(Fixnum) || option <= 0
      end
    end
  end
end
