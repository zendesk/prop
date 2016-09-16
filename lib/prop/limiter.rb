# frozen_string_literal: true
require 'prop/rate_limited'
require 'prop/key'
require 'prop/options'
require 'prop/interval_strategy'
require 'prop/leaky_bucket_strategy'

module Prop
  class Limiter

    class << self
      attr_accessor :handles, :before_throttle_callback, :cache

      def read(&blk)
        raise "Use .cache = "
      end

      def write(&blk)
        raise "Use .cache = "
      end

      def cache=(cache)
        [:read, :write, :increment, :decrement].each do |method|
          next if cache.respond_to?(method)
          raise ArgumentError, "Cache needs to respond to #{method}"
        end

        # https://github.com/petergoldstein/dalli/pull/481
        if defined?(ActiveSupport::Cache::DalliStore) &&
            cache.is_a?(ActiveSupport::Cache::DalliStore) &&
            Gem::Version.new(Dalli::VERSION) <= Gem::Version.new("2.7.4")
          raise "Upgrade to dalli 2.7.5+ to use prop v2, it fixes a local_cache vs increment bug"
        end

        @cache = cache
      end

      def before_throttle(&blk)
        self.before_throttle_callback = blk
      end

      # Public: Registers a handle for rate limiting
      #
      # handle   - the name of the handle you wish to use in your code, e.g. :login_attempt
      # defaults - the settings for this handle, e.g. { threshold: 5, interval: 5.minutes }
      #
      # Raises Prop::RateLimited if the number if the threshold for this handle has been reached
      def configure(handle, defaults)
        raise ArgumentError.new("Invalid threshold setting") unless defaults[:threshold].to_i > 0
        raise ArgumentError.new("Invalid interval setting")  unless defaults[:interval].to_i > 0

        self.handles ||= {}
        self.handles[handle] = defaults
      end

      # Public: Disables Prop for a block of code
      #
      # block    - a block of code within which Prop will not raise
      def disabled(&block)
        @disabled = true
        yield
      ensure
        @disabled = false
      end

      # Public: Records a single action for the given handle/key combination.
      #
      # handle  - the registered handle associated with the action
      # key     - a custom request specific key, e.g. [ account.id, "download", request.remote_ip ]
      # options - request specific overrides to the defaults configured for this handle
      # (optional) a block of code that this throttle is guarding
      #
      # Returns true if the threshold for this handle has been reached, else returns false
      def throttle(handle, key = nil, options = {})
        options, cache_key = prepare(handle, key, options)
        throttled = _throttle(handle, key, cache_key, options).first
        block_given? && !throttled ? yield : throttled
      end

      # Public: Records a single action for the given handle/key combination.
      #
      # handle  - the registered handle associated with the action
      # key     - a custom request specific key, e.g. [ account.id, "download", request.remote_ip ]
      # options - request specific overrides to the defaults configured for this handle
      # (optional) a block of code that this throttle is guarding
      #
      # Raises Prop::RateLimited if the threshold for this handle has been reached
      # Returns the value of the block if given a such, otherwise the current count of the throttle
      def throttle!(handle, key = nil, options = {}, &block)
        options, cache_key = prepare(handle, key, options)
        throttled, counter = _throttle(handle, key, cache_key, options)

        if throttled
          raise Prop::RateLimited.new(options.merge(
            cache_key: cache_key,
            handle: handle,
            first_throttled: (throttled == :first_throttled)
          ))
        end

        block_given? ? yield : counter
      end

      # Public: Is the given handle/key combination currently throttled ?
      #
      # handle   - the throttle identifier
      # key      - the associated key
      #
      # Returns true if a call to `throttle!` with same parameters would raise, otherwise false
      def throttled?(handle, key = nil, options = {})
        options, cache_key = prepare(handle, key, options)
        counter = @strategy.counter(cache_key, options)
        @strategy.compare_threshold?(counter, :>=, options)
      end

      # Public: Resets a specific throttle
      #
      # handle   - the throttle identifier
      # key      - the associated key
      #
      # Returns nothing
      def reset(handle, key = nil, options = {})
        _options, cache_key = prepare(handle, key, options)
        @strategy.reset(cache_key)
      end

      # Public: Counts the number of times the given handle/key combination has been hit in the current window
      #
      # handle   - the throttle identifier
      # key      - the associated key
      #
      # Returns a count of hits in the current window
      def count(handle, key = nil, options = {})
        options, cache_key = prepare(handle, key, options)
        @strategy.counter(cache_key, options)
      end
      alias :query :count

      def handles
        @handles ||= {}
      end
      alias :configurations :handles

      private

      def _throttle(handle, key, cache_key, options)
        return [false, @strategy.zero_counter] if disabled?

        counter = options.key?(:decrement) ?
          @strategy.decrement(cache_key, options.fetch(:decrement), options) :
          @strategy.increment(cache_key, options.fetch(:increment, 1), options)

        if @strategy.compare_threshold?(counter, :>, options)
          before_throttle_callback &&
            before_throttle_callback.call(handle, key, options[:threshold], options[:interval])

          result = if options[:first_throttled] && @strategy.first_throttled?(counter, options)
            :first_throttled
          else
            true
          end

          [result, counter]
        else
          [false, counter]
        end
      end

      def disabled?
        defined?(@disabled) && !!@disabled
      end

      def prepare(handle, key, params)
        unless defaults = handles[handle]
          raise KeyError.new("No such handle configured: #{handle.inspect}")
        end

        options = Prop::Options.build(key: key, params: params, defaults: defaults)

        @strategy = options.fetch(:strategy)

        cache_key = @strategy.build(key: key, handle: handle, interval: options[:interval])

        [ options, cache_key ]
      end
    end
  end
end
