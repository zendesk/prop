require 'helper'
require 'prop/middleware'
require 'prop/rate_limited'

class TestMiddleware < Test::Unit::TestCase

  context Prop::Middleware do
    setup do
      @app = stub()
      @env = {}
      @middleware = Prop::Middleware.new(@app)
    end

    context "when the app call completes" do
      setup do
        @app.expects(:call).with(@env).returns("response")
      end

      should "return the response" do
        assert_equal "response", @middleware.call(@env)
      end
    end

    context "when the app call results in a raised throttle" do
      setup do
        @app.expects(:call).with(@env).raises(Prop::RateLimited.new(:handle => "foo", :threshold => 10, :interval => 60, :cache_key => "wibble", :description => "Boom!"))
      end

      should "return the rate limited message" do
        response = @middleware.call(@env)

        assert_equal 429, response[0]
        assert_equal ["Boom!"], response[2]
      end
    end
  end
end