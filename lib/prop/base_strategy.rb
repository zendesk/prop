require 'prop/limiter'
require 'prop/key'

module Prop
  class BaseStrategy
    class << self
      def counter(cache_key, options)
        Prop::Limiter.reader.call(cache_key).to_i
      end

      def increment(cache_key, options, counter)
        increment = options.key?(:increment) ? options[:increment].to_i : 1
        Prop::Limiter.writer.call(cache_key, counter + increment)
      end

      def reset(cache_key)
        Prop::Limiter.writer.call(cache_key, 0)
      end

      def current_count(cache_key)
        Prop::Limiter.reader.call(cache_key).to_i
      end

      def at_threshold?(counter, options)
        counter >= options[:threshold]
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
    end
  end
end
