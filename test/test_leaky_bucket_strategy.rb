# frozen_string_literal: true
require_relative 'helper'

describe Prop::LeakyBucketStrategy do
  before do
    @key = "leaky_bucket_cache_key"
    setup_fake_store
    freeze_time
  end

  def increment_test_helper(expected_over_limit, expected_bucket, amount, options)
    assert_equal([expected_over_limit, expected_bucket], Prop::LeakyBucketStrategy.increment(@key, amount, options))
    assert_equal(expected_bucket, Prop::Limiter.cache.read(@key))
  end

  def decrement_test_helper(expected_over_limit, expected_bucket, amount, options)
    assert_equal([expected_over_limit, expected_bucket], Prop::LeakyBucketStrategy.decrement(@key, amount, options))
    assert_equal(expected_bucket, Prop::Limiter.cache.read(@key))
  end

  describe "#_throttle_leaky_bucket" do
    it "increments bucket by default" do
      Prop::LeakyBucketStrategy._throttle_leaky_bucket('handle', "foo", @key, interval: 1, threshold: 10, burst_rate: 15)
      assert_equal({bucket: 1, last_leak_time: @time.to_i, over_limit: false}, Prop::Limiter.cache.read(@key))
    end

    it "increments bucket when specified" do
      Prop::LeakyBucketStrategy._throttle_leaky_bucket('handle', "foo", @key, interval: 1, threshold: 10, burst_rate: 15, increment: 2)
      assert_equal({bucket: 2, last_leak_time: @time.to_i, over_limit: false}, Prop::Limiter.cache.read(@key))
    end

    it "decrements bucket" do
      Prop::Limiter.cache.write(@key, { bucket: 10, last_leak_time: @time.to_i})
      Prop::LeakyBucketStrategy._throttle_leaky_bucket('handle', "foo", @key, interval: 1, threshold: 10, burst_rate: 15, decrement: 5)
      assert_equal({bucket: 5, last_leak_time: @time.to_i, over_limit: false}, Prop::Limiter.cache.read(@key))
    end
  end

  describe "#counter" do
    describe "when cache[@key] is nil" do
      it "returns an empty bucket" do
        bucket_expected = { bucket: 0, last_leak_time: 0, over_limit: false}
        assert_equal(Prop::LeakyBucketStrategy.counter(@key, interval: 1, threshold: 10), bucket_expected)
      end
    end

    describe "when @store[@key] has an existing value" do
      before do
        Prop::Limiter.cache.write(@key, bucket: 100, last_leak_time: @time.to_i)
      end

      it "returns the current bucket" do
        bucket_expected = { bucket: 100, last_leak_time: @time.to_i }
        assert_equal(Prop::LeakyBucketStrategy.counter(@key, interval: 1, threshold: 10), bucket_expected)
      end
    end
  end

  describe "#increment" do
    it "increments an empty bucket" do
      expected_bucket =  {bucket: 1, last_leak_time: @time.to_i, over_limit: false}
      increment_test_helper(false, expected_bucket,1, interval: 1, threshold: 10, burst_rate: 15)
    end

    describe "when increment amount is 1" do
      it "increments an existing bucket above burst rate and sets over_limit to true" do
        expected_bucket = {bucket: 15, last_leak_time: @time.to_i, over_limit: true}
        Prop::Limiter.cache.write(@key, expected_bucket)
        increment_test_helper(true, expected_bucket, 1, interval: 1, threshold: 10, burst_rate: 15)
      end

      it "increments an existing bucket to value below burst and over_limit to false" do
        expected_bucket = {bucket: 11, last_leak_time: @time.to_i, over_limit: false}
        Prop::Limiter.cache.write(@key, { bucket: 10, last_leak_time: @time.to_i})
        increment_test_helper(false, expected_bucket, 1, interval: 1, threshold: 10, burst_rate: 15)
      end

      it "leaks bucket at proper rate" do
        expected_bucket = {bucket: 6, last_leak_time: @time.to_i, over_limit: false}
        Prop::Limiter.cache.write(@key, { bucket: 10, last_leak_time: @time.to_i - 4 })
        increment_test_helper(false, expected_bucket, 0, interval: 60, threshold: 60, burst_rate: 100)
      end
    end

    describe "when increment amount > 1" do
      it "increments an existing bucket to value below burst and over_limit to false" do
        expected_bucket = {bucket: 15, last_leak_time: @time.to_i, over_limit: false}
        Prop::Limiter.cache.write(@key, { bucket: 10, last_leak_time: @time.to_i})
        increment_test_helper(false, expected_bucket, 5, interval: 1, threshold: 10, burst_rate: 20)
      end

      it "sets value to exactly burst_rate and sets over_limit to false" do
        expected_bucket = {bucket: 20, last_leak_time: @time.to_i, over_limit: false}
        Prop::Limiter.cache.write(@key, { bucket: 9, last_leak_time: @time.to_i })
        increment_test_helper(false, expected_bucket, 11, interval: 60, threshold: 10, burst_rate: 20)
      end

      it "leaks bucket at proper rate and update bucket" do
        # bucket updated 5 seconds ago with leak rate of 1/second (threshold / interval)
        expected_bucket = {bucket: 90, last_leak_time: @time.to_i, over_limit: false}
        Prop::Limiter.cache.write(@key, { bucket: 85, last_leak_time: @time.to_i - 5 })
        increment_test_helper(false, expected_bucket, 10, interval: 60, threshold: 60, burst_rate: 100)
      end

      it "increment would exceed burst rate and doesn't change bucket value and over_limit to true" do
        # bucket updated 5 seconds ago with leak rate of 1/second (threshold / interval)
        expected_bucket = {bucket: 85, last_leak_time: @time.to_i, over_limit: true}
        Prop::Limiter.cache.write(@key, { bucket: 85, last_leak_time: @time.to_i })
        increment_test_helper(true, expected_bucket, 20, interval: 60, threshold: 60, burst_rate: 100)
      end

      it "leaks bucket at proper rate and update bucket" do
        expected_bucket = {bucket: 90, last_leak_time: @time.to_i, over_limit: false}
        Prop::Limiter.cache.write(@key, { bucket: 85, last_leak_time: @time.to_i - 5 })
        increment_test_helper(false, expected_bucket, 10, interval: 60, threshold: 60, burst_rate: 100)
      end
    end

    it "does not leak bucket when leak amount is less than one" do
      # leak_rate = (now - last_leak_time) / interval
      # leak_amount = leak_rate * threshold
      # in this case it should be leak_rate = 0.1, 1 second between updates / interval
      # leak_amount = 0.9, 0.1 * 9 which truncs to 0 so no leakage
      expected_bucket = {bucket: 5, last_leak_time: @time.to_i-2, over_limit: false}
      Prop::Limiter.cache.write(@key, { bucket: 5, last_leak_time: @time.to_i - 2 })
      increment_test_helper(false, expected_bucket, 0, interval: 10, threshold: 4, burst_rate: 15)
    end

  end

  describe "#decrement" do
    it "returns 0 when decrement an empty bucket" do
      Prop::LeakyBucketStrategy.decrement(@key, 5, interval: 1, threshold: 10, burst_rate: 15)
      assert_equal(Prop::Limiter.cache.read(@key), {bucket: 0, last_leak_time: @time.to_i, over_limit: false})
    end

    it "decrements but does not leak if time doesn't change" do
      expected_bucket = {bucket: 2, last_leak_time: @time.to_i, over_limit: false}
      Prop::Limiter.cache.write(@key, { bucket: 5, last_leak_time: @time.to_i })
      decrement_test_helper(false, expected_bucket, 3, interval: 1, threshold: 10, burst_rate: 15)
    end

    it "decrements and leaks bucket" do
      # bucket updated 5 seconds ago with leak rate of 1/second
      expected_bucket = {bucket: 4, last_leak_time: @time.to_i, over_limit: false}
      Prop::Limiter.cache.write(@key, { bucket: 10, last_leak_time: @time.to_i - 5 })
      decrement_test_helper(false, expected_bucket, 1, interval: 60, threshold: 60, burst_rate: 100)
    end

    it "decrements and does not leak bucket if interval is too short" do
      # leak_rate = (now - last_leak_time) / interval
      # leak_amount = leak_rate * threshold
      # in this case it should be leak_rate = 0.1, 1 second between updates / interval
      # leak_amount = 0.9, 0.1 * 9 which truncs to 0 so no leakage
      expected_bucket = {bucket: 9, last_leak_time: @time.to_i-1, over_limit: false}
      Prop::Limiter.cache.write(@key, { bucket: 10, last_leak_time: @time.to_i - 1 })
      decrement_test_helper(false, expected_bucket, 1, interval: 10, threshold: 9, burst_rate: 100)
    end
  end

  describe "#reset" do
    before do
      Prop::Limiter.cache.write(@key, bucket: 100, last_leak_time: @time.to_i)
    end

    it "resets the bucket" do
      bucket_expected = { bucket: 0, last_leak_time: 0, over_limit: false }
      Prop::LeakyBucketStrategy.reset(@key)
      assert_equal(Prop::Limiter.cache.read(@key), bucket_expected)
    end
  end

  describe "#build" do
    it "returns a hexdigested key" do
      _(Prop::LeakyBucketStrategy.build(handle: :hello, key: [ "foo", 2, :bar ])).must_match(/prop\/leaky_bucket\/[a-f0-9]+/)
    end
  end

  describe "#validate_options!" do
    it "raise when burst rate is not valid" do
      @args = { threshold: 10, interval: 10, strategy: :leaky_bucket, burst_rate: 'five' }
      assert_raises(ArgumentError) { Prop::LeakyBucketStrategy.validate_options!(@args) }
    end

    describe "when :increment less than zero" do
      it "raises an exception" do
        @args = { threshold: 1, interval: 1, strategy: :leaky_bucket, burst_rate: 2, increment: -1}
        assert_raises(ArgumentError) { Prop::LeakyBucketStrategy.validate_options!(@args) }
      end
    end
  end
end
