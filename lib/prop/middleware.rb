module Prop

  # Convenience middleware that conveys the message configured on a Prop handle as well
  # as time left before the current window has passed in a Retry-After header.
  class Middleware

    # Default error handler
    class DefaultErrorHandler
      def self.call(env, error)
        body    = error.description || "This action has been rate limited"
        headers = { "Content-Type" => "text/plain", "Content-Length" => "#{body.size}", "Retry-After" => "#{error.retry_after}" }

        [ 429, headers, [ body ]]
      end
    end

    def initialize(app, options = {})
      @app     = app
      @options = options
      @handler = options[:error_handler] || DefaultErrorHandler
    end

    def call(env)
      begin
        @app.call(env)
      rescue Prop::RateLimited => e
        render_response(env, e)
      end
    end

    protected

    def render_response(env, error)
      @handler.call(env, error)
    end
  end

end
