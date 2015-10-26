require_relative 'helper'

describe Prop::RateLimited do
  before do
    freeze_time 1333685680

    Prop.configure :foo, threshold: 10, interval: 60, category: :api

    @error = Prop::RateLimited.new(
      handle: :foo,
      threshold: 10,
      interval: 60,
      cache_key: "wibble",
      description: "Boom!",
      strategy: Prop::IntervalStrategy
    )
  end

  describe "#initialize" do
    it "returns an error instance" do
      @error.must_be_kind_of StandardError
      @error.must_be_kind_of Prop::RateLimited

      @error.handle.must_equal :foo
      @error.cache_key.must_equal "wibble"
      @error.description.must_equal "Boom!"
      @error.message.must_equal "foo threshold of 10 tries per 60s exceeded for key nil, hash wibble"
      @error.retry_after.must_equal 20
    end
  end

  describe "#config" do
    it "returns the original configuration" do
      @error.config[:threshold].must_equal 10
      @error.config[:interval].must_equal 60
      @error.config[:category].must_equal :api
    end
  end
end
