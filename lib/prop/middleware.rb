module Prop

  # Convenience middleware that conveys the message configured on a Prop handle as well
  # as time left before the current window has passed in a Retry-After header.
  class Middleware

    # Default error handler
    class DefaultErrorHandler
      def self.call(error)
        body    = error.description || "This action has been rate limited"
        headers = { "Content-Type" => "text/plain", "Content-Length" => body.size, "Retry-After" => error.retry_after }

        [ 429, headers, [ body ]]
      end
    end

    class << self
      attr_accessor :error_handler
    end

    self.error_handler = DefaultErrorHandler

    def initialize(app)
      @app = app
    end

    def call(env, options = {})
      begin
        @app.call(env)
      rescue Prop::RateLimited => e
        Middleware.error_handler.call(e)
      end
    end
  end

end
