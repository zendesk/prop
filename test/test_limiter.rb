require_relative 'helper'

describe Prop::Limiter do
  before do
    @store = {}
    @cache_key = "cache_key"

    Prop::Limiter.read  { |key| @store[key] }
    Prop::Limiter.write { |key, value| @store[key] = value }

    @start = Time.now
    Time.stubs(:now).returns(@start)
  end

  describe "IntervalStrategy" do
    before do
      Prop::Limiter.configure(:something, threshold: 10, interval: 10)
      Prop::IntervalStrategy.stubs(:build).returns(@cache_key)
      Prop.reset(:something)
    end

    after do
      @store.delete(@cache_key)
    end

    describe "#throttle" do
      it "returns false when disabled" do
        Prop::Limiter.disabled { Prop.throttle(:something) }.must_equal false
      end

      describe "and the threshold has been reached" do
        before { Prop::IntervalStrategy.stubs(:at_threshold?).returns(true) }

        it "returns true" do
          assert Prop.throttle(:something)
        end

        it "does not increment the throttle count" do
          Prop.throttle(:something)

          Prop.count(:something).must_equal 0
        end

        it "does not execute a block" do
          test_block_executed = false
          Prop.throttle(:something) { test_block_executed = true }
          refute test_block_executed
        end

        it "invokes before_throttle callback" do
          Prop.before_throttle do |handle, key, threshold, interval|
            @handle    = handle
            @key       = key
            @threshold = threshold
            @interval  = interval
          end

          Prop.throttle(:something, [:extra])

          @handle.must_equal :something
          @key.must_equal [:extra]
          @threshold.must_equal 10
          @interval.must_equal 10
        end
      end

      describe "and the threshold has not been reached" do
        before { Prop::IntervalStrategy.stubs(:at_threshold?).returns(false) }

        it "returns false" do
          refute Prop.throttle(:something)
        end

        it "increments the throttle count by one" do
          Prop.throttle(:something)

          Prop.count(:something).must_equal 1
        end

        it "increments the throttle count by the specified number when provided" do
          Prop.throttle(:something, nil, increment: 5)

          Prop.count(:something).must_equal 5
        end

        it "executes a block" do
          test_block_executed = false
          Prop.throttle(:something) { test_block_executed = true }
          assert test_block_executed
        end
      end
    end

    describe "#throttle!" do
      it "throttles the given handle/key combination" do
        Prop::Limiter.expects(:throttle).with(
          :something,
          :key,
          {
            threshold: 10,
            interval:  10,
            key:       'key',
            strategy: Prop::IntervalStrategy,
            options:  true
          }
        )

        Prop.throttle!(:something, :key, options: true)
      end

      describe "when the threshold has been reached" do
        before { Prop::Limiter.stubs(:throttle).returns(true) }

        it "raises a rate-limited exception" do
          assert_raises(Prop::RateLimited) { Prop.throttle!(:something) }
        end

        it "does not executes a block" do
          test_block_executed = false
          assert_raises Prop::RateLimited do
            Prop.throttle!(:something) { test_block_executed = true }
          end
          refute test_block_executed
        end
      end

      describe "when the threshold has not been reached" do
        it "returns the counter value" do
          Prop.throttle!(:something).must_equal Prop.count(:something)
        end

        it "returns the return value of a block" do
          Prop.throttle!(:something) { 'block_value' }.must_equal 'block_value'
        end
      end
    end
  end

  describe "LeakyBucketStrategy" do
    before do
      Prop::Limiter.configure(:something, threshold: 10, interval: 1, burst_rate: 100, strategy: :leaky_bucket)
      Prop::LeakyBucketStrategy.stubs(:build).returns(@cache_key)
    end

    after do
      @store.delete(@cache_key)
    end

    describe "#throttle" do
      describe "when the bucket is not full" do
        it "increments the count number and saves timestamp in the bucket" do
          refute Prop::Limiter.throttle(:something)
          Prop::Limiter.count(:something).must_equal(
            bucket: 1, last_updated: @start.to_i, burst_rate: 100
          )
        end
      end

      describe "when the bucket is full" do
        before do
          Prop::LeakyBucketStrategy.stubs(:at_threshold?).returns(true)
        end

        it "returns true and doesn't increment the count number in the bucket" do
          assert Prop::Limiter.throttle(:something)
          Prop::Limiter.count(:something).must_equal(
            bucket: 0, last_updated: @start.to_i, burst_rate: 100
          )
        end
      end
    end

    describe "#throttle!" do
      describe "when the bucket is full" do
        before do
          Prop::Limiter.expects(:throttle).returns(true)
        end

        it "raises RateLimited exception" do
          assert_raises Prop::RateLimited do
            Prop::Limiter.throttle!(:something)
          end
        end
      end

      describe "when the bucket is not full" do
        it "returns the bucket" do
          expected_bucket = { bucket: 1, last_updated: @start.to_i, burst_rate: 100 }
          Prop::Limiter.throttle!(:something).must_equal expected_bucket
        end

        it "throttles the given handle/key combination" do
          Prop::Limiter.expects(:throttle).with(
            :something,
            :key,
            {
              threshold:  10,
              interval:   1,
              key:        'key',
              burst_rate: 100,
              strategy:   Prop::LeakyBucketStrategy,
              options:    true
            }
          )

          Prop::Limiter.throttle!(:something, :key, options: true)
        end
      end
    end
  end
end
