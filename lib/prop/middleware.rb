module Prop
  # Convenience middleware that conveys the message configured on a Prop handle as well
  # as time left before the current window has passed in a Retry-After header.
  class Middleware

    def initialize(app)
      @app = app
    end

    def call(env, options = {})
      begin
        @app.call(env)
      rescue Prop::RateLimited => e
        body    = e.description || "This action has been rate limited"

        headers = { "Content-Type" => "text/plain", "Content-Length" => body.size }
        headers["Retry-After"] = e.retry_after if e.retry_after > 0

        [ 429, headers, [ body ]]
      end
    end
  end
end
