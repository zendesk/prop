# frozen_string_literal: true
require_relative 'helper'

describe Prop::Limiter do
  context "both strategies are being used simultaneously" do
    before do
      cache = setup_fake_store
      def cache.increment(_, _)
        sleep 0.0001
      end

      Prop.configure(:interval, threshold: 1, interval: 1.minute)
      Prop.configure(:leaky_bucket, strategy: :leaky_bucket, burst_rate: 2, threshold: 1, interval: 1.minute)
    end

    def self.it_handles_concurrency(method)
      it "handles concurrency" do
        calculated_value = 0

        interval_thread = Thread.new do
           Prop.send(method, :interval) { calculated_value += 1 }
        end
        leaky_bucket_strategy_thread = Thread.new do
          Prop.send(method, :leaky_bucket) { calculated_value += 1 }
        end
        interval_thread.join
        leaky_bucket_strategy_thread.join

        calculated_value.must_equal 2
      end
    end

    describe "#throttle" do
      it_handles_concurrency('throttle')
    end

    describe "#throttle!" do
      it_handles_concurrency('throttle!')
    end
  end
end

describe Prop::Limiter do
  before do
    @cache_key = "cache_key"
    setup_fake_store
    freeze_time
  end

  describe Prop::IntervalStrategy do
    before do
      Prop::Limiter.configure(:something, threshold: 10, interval: 10)
      Prop::IntervalStrategy.stubs(:build).returns(@cache_key)
      Prop.reset(:something)
    end

    describe "#throttle" do
      it "returns false when disabled" do
        Prop::Limiter.disabled { Prop.throttle(:something) }.must_equal false
      end

      it "supports decrement and can below 0" do
        Prop.throttle(:something)
        Prop.count(:something).must_equal 1

        Prop.throttle(:something, nil, decrement: 5)
        Prop.count(:something).must_equal -4
      end

      describe "and the threshold has been reached" do
        before { Prop::IntervalStrategy.stubs(:compare_threshold?).returns(true) }

        it "returns true" do
          assert Prop.throttle(:something)
        end
        it "increments the throttle count" do
          Prop.throttle(:something)
          Prop.count(:something).must_equal 1
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
        before { Prop::IntervalStrategy.stubs(:compare_threshold?).returns(false) }

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
          calls = []
          Prop.throttle(:something) { calls << true }.must_equal [true]
        end
      end
    end

    describe "#throttle!" do
      it "throttles the given handle/key combination" do
        Prop::Limiter.expects(:_throttle).with(
          Prop::IntervalStrategy,
          :something,
          :key,
          'cache_key',
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
        before { Prop::Limiter.stubs(:_throttle).returns([true]) }

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
          calls = []
          Prop.throttle!(:something) { calls << 'block_value' }.must_equal ['block_value']
        end
      end
    end
  end

  describe Prop::LeakyBucketStrategy do
    before do
      Prop::Limiter.configure(:something, threshold: 10, interval: 60, burst_rate: 100, strategy: :leaky_bucket)
      Prop::LeakyBucketStrategy.stubs(:build).returns(@cache_key)
    end

    describe "#throttle" do
      describe "when the bucket is not full" do
        it "increments the count number and saves timestamp in the bucket" do
          refute Prop::Limiter.throttle(:something)
          Prop::Limiter.count(:something).must_equal(
            bucket: 1, last_leak_time: @time.to_i, over_limit: false
          )
        end
      end
    end

    describe "#throttle!" do
      describe "when the bucket is full" do
        it "raises" do
          Prop::Limiter.expects(:_throttle).returns([true, 1])
          assert_raises Prop::RateLimited do
            Prop::Limiter.throttle!(:something)
          end
        end
      end

      describe "when the bucket is not full" do
        it "returns the bucket" do
          expected_bucket = { bucket: 1, last_leak_time: @time.to_i, over_limit: false }
          Prop::Limiter.throttle!(:something).must_equal expected_bucket
        end

        it "throttles the given handle/key combination" do
          Prop::Limiter.expects(:_throttle).with(
            Prop::LeakyBucketStrategy,
            :something,
            :key,
            'cache_key',
            {
              threshold:  10,
              interval:   60,
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
