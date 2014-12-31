require 'prop/rate_limited'
require 'prop/key'
require 'prop/options'

module Prop
  class Limiter

    class << self
      attr_accessor :handles, :reader, :writer, :before_throttle_callback

      def read(&blk)
        self.reader = blk
      end

      def write(&blk)
        self.writer = blk
      end

      def before_throttle(&blk)
        self.before_throttle_callback = blk
      end

      # Public: Registers a handle for rate limiting
      #
      # handle   - the name of the handle you wish to use in your code, e.g. :login_attempt
      # defaults - the settings for this handle, e.g. { :threshold => 5, :interval => 5.minutes }
      #
      # Raises Prop::RateLimited if the number if the threshold for this handle has been reached
      def configure(handle, defaults)
        raise RuntimeError.new("Invalid threshold setting") unless defaults[:threshold].to_i > 0
        raise RuntimeError.new("Invalid interval setting")  unless defaults[:interval].to_i > 0

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
        counter = reader.call(cache_key).to_i

        unless disabled?
          if at_threshold?(counter, options[:threshold])
            unless before_throttle_callback.nil?
              before_throttle_callback.call(handle, key, options[:threshold], options[:interval])
            end

            true
          else
            increment = options.key?(:increment) ? options[:increment].to_i : 1
            writer.call(cache_key, counter + increment)

            yield if block_given?

            false
          end
        end
      end

      # Public: Records a single action for the given handle/key combination.
      #
      # handle  - the registered handle associated with the action
      # key     - a custom request specific key, e.g. [ account.id, "download", request.remote_ip ]
      # options - request specific overrides to the defaults configured for this handle
      # (optional) a block of code that this throttle is guarding
      #
      # Raises Prop::RateLimited if the number if the threshold for this handle has been reached
      # Returns the value of the block if given a such, otherwise the current count of the throttle
      def throttle!(handle, key = nil, options = {})
        options, cache_key = prepare(handle, key, options)

        if throttle(handle, key, options)
          raise Prop::RateLimited.new(options.merge(:cache_key => cache_key, :handle => handle))
        end

        block_given? ? yield : reader.call(cache_key).to_i
      end

      # Public: Allows to query whether the given handle/key combination is currently throttled
      #
      # handle   - the throttle identifier
      # key      - the associated key
      #
      # Returns true if a call to `throttle!` with same parameters would raise, otherwise false
      def throttled?(handle, key = nil, options = {})
        options, cache_key = prepare(handle, key, options)
        reader.call(cache_key).to_i >= options[:threshold]
      end

      # Public: Resets a specific throttle
      #
      # handle   - the throttle identifier
      # key      - the associated key
      #
      # Returns nothing
      def reset(handle, key = nil, options = {})
        options, cache_key = prepare(handle, key, options)
        writer.call(cache_key, 0)
      end

      # Public: Counts the number of times the given handle/key combination has been hit in the current window
      #
      # handle   - the throttle identifier
      # key      - the associated key
      #
      # Returns a count of hits in the current window
      def count(handle, key = nil, options = {})
        options, cache_key = prepare(handle, key, options)
        reader.call(cache_key).to_i
      end
      alias :query :count

      def handles
        @handles ||= {}
      end

      private

      def at_threshold?(mark, threshold)
        mark >= threshold
      end

      def disabled?
        !!@disabled
      end

      def prepare(handle, key, params)
        raise RuntimeError.new("No such handle configured: #{handle.inspect}") unless (handles || {}).key?(handle)

        defaults  = handles[handle]
        options   = Prop::Options.build(:key => key, :params => params, :defaults => defaults)
        cache_key = Prop::Key.build(:key => key, :handle => handle, :interval => options[:interval])

        [ options, cache_key ]
      end
    end
  end
end
