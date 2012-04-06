require 'helper'

class TestRateLimited < Test::Unit::TestCase

  context Prop::RateLimited do
    context "#initialize" do
      setup do
        time = Time.at(1333685680)
        Time.stubs(:now).returns(time)

        @error = Prop::RateLimited.new(:handle => "foo", :threshold => 10, :interval => 60, :cache_key => "wibble", :description => "Boom!")
      end

      should "return an error instance" do
        assert @error.is_a?(StandardError)
        assert @error.is_a?(Prop::RateLimited)

        assert_equal "foo", @error.handle
        assert_equal "wibble", @error.cache_key
        assert_equal "Boom!", @error.description
        assert_equal "foo threshold of 10/60s exceeded for key 'wibble'", @error.message
        assert_equal 20, @error.retry_after
      end
    end

  end
end