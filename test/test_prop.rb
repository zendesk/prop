require_relative 'helper'

# Integration level tests
describe Prop do
  before do
    setup_fake_store
    freeze_time
  end

  describe "#defaults" do
    it "raise errors on invalid configuation" do
      assert_raises(ArgumentError) do
        Prop.configure :hello_there, threshold: 20, interval: 'hello'
      end

      assert_raises(ArgumentError) do
        Prop.configure :hello_there, threshold: 'wibble', interval: 100
      end
    end

    it "result in a default handle" do
      Prop.configure :hello_there, threshold: 4, interval: 10
      4.times do |i|
        Prop.throttle!(:hello_there, 'some key').must_equal i + 1
      end

      assert_raises(Prop::RateLimited) { Prop.throttle!(:hello_there, 'some key') }
      Prop.throttle!(:hello_there, 'some key', threshold: 20).must_equal 6
    end

    it "create a handle accepts various cache key types" do
      Prop.configure :hello_there, threshold: 4, interval: 10
      Prop.throttle!(:hello_there, 5).must_equal 1
      Prop.throttle!(:hello_there, 5).must_equal 2
      Prop.throttle!(:hello_there, '6').must_equal 1
      Prop.throttle!(:hello_there, '6').must_equal 2
      Prop.throttle!(:hello_there, [ 5, '6' ]).must_equal 1
      Prop.throttle!(:hello_there, [ 5, '6' ]).must_equal 2
    end
  end

  describe "#disable" do
    before do
      Prop.configure :hello, threshold: 10, interval: 10
    end

    it "not increase the throttle" do
      Prop.throttle!(:hello).must_equal 1
      Prop.throttle!(:hello).must_equal 2
      Prop.disabled do
        Prop.throttle!(:hello).must_equal 2
        Prop.throttle!(:hello).must_equal 2
        assert Prop::Limiter.send(:disabled?)
      end
      refute Prop::Limiter.send(:disabled?)
      Prop.throttle!(:hello).must_equal 3
    end
  end

  describe "#reset" do
    describe "when use interval strategy" do
      before do
        Prop.configure :hello, threshold: 10, interval: 10

        5.times do |i|
          Prop.throttle!(:hello).must_equal i + 1
        end
      end

      it "set the correct counter to 0" do
        Prop.throttle!(:hello, 'wibble')
        Prop.throttle!(:hello, 'wibble')

        Prop.reset(:hello)
        Prop.throttle!(:hello).must_equal 1

        Prop.throttle!(:hello, 'wibble').must_equal 3
        Prop.reset(:hello, 'wibble')
        Prop.throttle!(:hello, 'wibble').must_equal 1
      end
    end

    describe "when use leaky bucket strategy" do
      before do
        Prop.configure :hello, threshold: 2, interval: 10, strategy: :leaky_bucket, burst_rate: 10

        5.times do |i|
          Prop.throttle!(:hello)[:bucket].must_equal i + 1
        end
      end

      it "set the correct counter to 0" do
        Prop.reset(:hello)
        Prop.throttle!(:hello)[:bucket].must_equal 1
      end
    end
  end

  describe "#throttled?" do
    describe "when use interval strategy" do
      it "return true once the threshold has been reached" do
        Prop.configure(:hello, threshold: 2, interval: 10)

        2.times do
          refute Prop.throttled?(:hello)
          refute Prop.throttle(:hello)
        end

        assert Prop.throttled?(:hello)
        assert Prop.throttle(:hello)
      end
    end

    describe "when use leaky bucket strategy" do
      it "return true once it was throttled" do
        Prop.configure(:hello, threshold: 1, interval: 10, strategy: :leaky_bucket, burst_rate: 2)

        2.times do
          refute Prop.throttled?(:hello)
          refute Prop.throttle(:hello)
        end

        assert Prop.throttled?(:hello)
        assert Prop.throttle(:hello)
      end
    end
  end

  describe "#count" do
    before do
      Prop.configure(:hello, threshold: 20, interval: 20)
      Prop.throttle!(:hello)
      Prop.throttle!(:hello)
    end

    it "be aliased by #count" do
      2.must_equal Prop.count(:hello)
    end

    it "return the number of hits on a throttle" do
      2.must_equal Prop.query(:hello)
    end
  end

  describe "#throttle!" do
    describe "when use interval strategy" do
      it "increment counter correctly" do
        Prop.configure(:hello, threshold: 20, interval: 20)
        3.times do |i|
          Prop.throttle!(:hello, nil, threshold: 10, interval: 10).must_equal i + 1
        end
      end

      it "reset counter when time window is passed" do
        Prop.configure(:hello, threshold: 20, interval: 20)
        3.times do |i|
          Prop.throttle!(:hello, nil, threshold: 10, interval: 10).must_equal i + 1
        end

        Time.stubs(:now).returns(@time + 20)

        3.times do |i|
          Prop.throttle!(:hello, nil, threshold: 10, interval: 10).must_equal i + 1
        end
      end

      it "increment the counter beyond the threshold" do
        Prop.configure(:hello, threshold: 5, interval: 1)
        10.times do
          Prop.throttle!(:hello) rescue nil
        end

        Prop.query(:hello).must_equal 10
      end

      it "raise Prop::RateLimited when the threshold is exceeded" do
        Prop.configure(:hello, threshold: 5, interval: 10, description: "Boom!")

        5.times do
          Prop.throttle!(:hello, nil)
        end

        assert_raises Prop::RateLimited do
          Prop.throttle!(:hello, nil)
        end

        e = assert_raises Prop::RateLimited do
          Prop.throttle!(:hello, nil)
        end

        e.handle.must_equal :hello
        e.message.must_include "5 tries per 10s exceeded for key"
        e.description.must_equal "Boom!"
        assert e.retry_after
      end
    end

    describe "when use leaky bucket strategy" do
      before do
        Prop.configure(:hello, threshold: 5, interval: 10, strategy: :leaky_bucket, burst_rate: 10, description: "Boom!")
      end

      it "increments counter correctly" do
        3.times do |i|
          Prop.throttle!(:hello)[:bucket].must_equal i + 1
        end
      end

      it "leaks when time window is passed" do
        3.times do |i|
          Prop.throttle!(:hello)[:bucket].must_equal i + 1
        end

        Time.stubs(:now).returns(@time + 10)

        10.times do |i|
          Prop.throttle!(:hello)[:bucket].must_equal i + 1
        end

        Time.stubs(:now).returns(@time + 30)
        Prop.query(:hello)[:bucket].must_equal 0
      end

      it "increments the counter beyond the burst rate" do
        15.times do
          Prop.throttle!(:hello) rescue nil
        end

        Prop.query(:hello)[:bucket].must_equal 15
      end

      it "raises Prop::RateLimited when the bucket is full" do
        10.times do
          Prop.throttle!(:hello, nil)
        end

        assert_raises Prop::RateLimited do
          Prop.throttle!(:hello, nil)
        end

        e = assert_raises Prop::RateLimited do
          Prop.throttle!(:hello, nil)
        end

        e.handle.must_equal :hello
        e.message.must_include "5 tries per 10s and burst rate 10 tries exceeded for key"
        e.description.must_equal "Boom!"
        assert e.retry_after
      end
    end

    it "support custom increments" do
      Prop.configure(:hello, threshold: 100, interval: 10)

      Prop.throttle!(:hello)
      Prop.throttle!(:hello)

      Prop.query(:hello).must_equal 2

      Prop.throttle!(:hello, nil, increment: 48)

      Prop.query(:hello).must_equal 50
    end

    it "raise a RuntimeError when a handle has not been configured" do
      assert_raises KeyError do
        Prop.throttle!(:no_such_handle, nil, threshold: 5, interval: 10)
      end
    end
  end

  describe "different handles with the same interval" do
    before do
      Prop.configure(:api_requests, threshold: 100, interval: 30)
      Prop.configure(:login_attempts, threshold: 10, interval: 30)
    end

    it "be counted separately" do
      user_id = 42
      Prop.throttle!(:api_requests, user_id)
      Prop.count(:api_requests, user_id).must_equal 1
      Prop.count(:login_attempts, user_id).must_equal 0
    end
  end

  describe "#configurations" do
    it "returns the configuration" do
      Prop.configure(:something, threshold: 100, interval: 30)
      config = Prop.configurations[:something]
      config[:threshold].must_equal 100
      config[:interval].must_equal 30
    end
  end
end
