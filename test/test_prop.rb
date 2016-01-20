require_relative 'helper'

# Integration level tests
describe Prop do
  def self.with_each_strategy
    [{}, {strategy: :leaky_bucket, burst_rate: 2}].each do |options|
      describe "with #{options[:strategy] || :interval} strategy" do
        yield options
      end
    end
  end

  def count(counter)
    counter.is_a?(Hash) ? counter[:bucket] : counter
  end

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
    with_each_strategy do |options|
      it "does not increase the throttle" do
        Prop.configure :hello, options.merge(threshold: 2, interval: 10)
        count(Prop.throttle!(:hello)).must_equal 1
        Prop.disabled do
          count(Prop.throttle!(:hello)).must_equal 0
        end
        count(Prop.throttle!(:hello)).must_equal 2
      end
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
    with_each_strategy do |options|
      before do
        Prop.configure(:hello, options.merge(threshold: 2, interval: 10))
        Prop.configure(:world, options.merge(threshold: 2, interval: 10))
      end

      it "return true once it was throttled" do
        2.times do
          refute Prop.throttled?(:hello)
          refute Prop.throttle(:hello)
        end

        assert Prop.throttled?(:hello)
        assert Prop.throttle(:hello)
      end

      it "counts different handles separately" do
          user_id = 42
          2.times { Prop.throttle!(:hello, user_id) }
          assert Prop.throttled?(:hello, user_id)
          refute Prop.throttled?(:world, user_id)
        end
    end
  end

  describe "#count" do
    before do
      Prop.configure(:hello, threshold: 20, interval: 20)
      Prop.throttle!(:hello)
      Prop.throttle!(:hello)
    end

    it "be aliased by #query" do
      Prop.query(:hello).must_equal 2
    end

    it "return the number of hits on a throttle" do
      Prop.count(:hello).must_equal 2
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

      it "support custom increments" do
        Prop.configure(:hello, threshold: 100, interval: 10)
        Prop.throttle!(:hello, nil, increment: 48)
        Prop.query(:hello).must_equal 48
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

      it "support custom increments" do
        Prop.configure(:hello, threshold: 100, interval: 10)
        Prop.throttle!(:hello, nil, increment: 48)
        Prop.query(:hello).must_equal 48
      end
    end

    it "raise a RuntimeError when a handle has not been configured" do
      assert_raises KeyError do
        Prop.throttle!(:no_such_handle, nil, threshold: 5, interval: 10)
      end
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
