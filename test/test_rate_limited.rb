require 'helper'

describe Prop::RateLimited do
  describe "#initialize" do
    before do
      time = Time.at(1333685680)
      Time.stubs(:now).returns(time)

      @error = Prop::RateLimited.new(:handle => "foo", :threshold => 10, :interval => 60, :cache_key => "wibble", :description => "Boom!")
    end

    it "return an error instance" do
      assert @error.is_a?(StandardError)
      assert @error.is_a?(Prop::RateLimited)

      assert_equal "foo", @error.handle
      assert_equal "wibble", @error.cache_key
      assert_equal "Boom!", @error.description
      assert_equal "foo threshold of 10 tries per 60s exceeded for key 'nil', hash wibble", @error.message
      assert_equal 20, @error.retry_after
    end
  end

end
