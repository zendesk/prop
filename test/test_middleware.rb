# frozen_string_literal: true
require_relative 'helper'

require 'prop/middleware'
require 'prop/rate_limited'

describe Prop::Middleware do
  before do
    @app = stub()
    @env = {}
    @middleware = Prop::Middleware.new(@app)
  end

  it "return the response" do
    @app.expects(:call).with(@env).returns("response")
    @middleware.call(@env).must_equal "response"
  end

  describe "when throttled" do
    before do
      options = {
        handle: "foo",
        threshold: 10,
        interval: 60,
        cache_key: "wibble",
        description: "Boom!",
        first_throttled: false, 
        strategy: Prop::IntervalStrategy
      }
      @app.expects(:call).with(@env).raises(Prop::RateLimited.new(options))
    end

    it "return the rate limited message when throttled" do
      status, _, body = @middleware.call(@env)

      status.must_equal 429
      body.must_equal ["Boom!"]
    end

    it "allow setting a custom error handler" do
      @middleware = Prop::Middleware.new(@app, error_handler: Proc.new { |env, error| "Oops" })
      @middleware.call(@env).must_equal "Oops"
    end
  end
end
