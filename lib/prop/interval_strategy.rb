# frozen_string_literal: true
require 'prop/options'
require 'prop/key'

module Prop
  class IntervalStrategy
    class << self
      def zero_counter
        0
      end

      def counter(cache_key, options)
        cache.read(cache_key).to_i
      end

      # options argument is kept for api consistency for all strategies
      def increment(cache_key, amount, options = {})
        raise ArgumentError, "Change amount must be a Integer, was #{amount.class}" unless amount.is_a?(Integer)
        cache.increment(cache_key, amount) || (cache.write(cache_key, amount, raw: true, expires_in: options.fetch(:interval, nil)) && amount) # WARNING: potential race condition
      end

      def decrement(cache_key, amount, options = {})
        raise ArgumentError, "Change amount must be a Integer, was #{amount.class}" unless amount.is_a?(Integer)
        cache.decrement(cache_key, amount) || (cache.write(cache_key, 0, raw: true, expires_in: options.fetch(:interval, nil)) && 0) # WARNING: potential race condition
      end

      def reset(cache_key, options = {})
        cache.write(cache_key, zero_counter, raw: true, expires_in: options.fetch(:interval, nil))
      end

      def compare_threshold?(counter, operator, options)
        return false unless counter
        counter.send operator, options.fetch(:threshold)
      end

      def first_throttled?(counter, options)
        (counter - options.fetch(:increment, 1)) <= options.fetch(:threshold)
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
        validate_threshold(options[:threshold], :threshold)
        validate_interval(options[:interval], :interval)

        amount = options[:increment] || options[:decrement]
        if amount
          raise ArgumentError.new(":increment or :decrement must be zero or a positive Integer") if !amount.is_a?(Integer) || amount < 0
        end
      end

      private

      def validate_threshold(option, key)
        raise ArgumentError.new("#{key.inspect} must be a non-negative Integer") if !option.is_a?(Integer) || option < 0
      end

      def validate_interval(option, key)
        raise ArgumentError.new("#{key.inspect} must be a positive Integer") if !option.is_a?(Integer) || option <= 0
      end

      def cache
        Prop::Limiter.cache
      end
    end
  end
end
