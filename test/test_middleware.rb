require_relative 'helper'

require 'prop/middleware'
require 'prop/rate_limited'


describe Prop::Middleware do
  before do
    @app = stub()
    @env = {}
    @middleware = Prop::Middleware.new(@app)
  end

  describe "when the app call completes" do
    before do
      @app.expects(:call).with(@env).returns("response")
    end

    it "return the response" do
      assert_equal "response", @middleware.call(@env)
    end
  end

  describe "when the app call results in a raised throttle" do
    before do
      @app.expects(:call).with(@env).raises(Prop::RateLimited.new(:handle => "foo", :threshold => 10, :interval => 60, :cache_key => "wibble", :description => "Boom!", :strategy => Prop::IntervalStrategy
                                            ))
    end

    it "return the rate limited message" do
      response = @middleware.call(@env)

      assert_equal 429, response[0]
      assert_equal ["Boom!"], response[2]
    end

    describe "with a custom error handler" do
      before do
        @middleware = Prop::Middleware.new(@app, :error_handler => Proc.new { |env, error| "Oops" })
      end

      it "allow setting a custom error handler" do
        assert_equal "Oops", @middleware.call(@env)
      end
    end
  end
end
