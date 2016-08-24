# frozen_string_literal: true
require_relative 'helper'

describe Prop::LeakyBucketStrategy do
  before do
    @key = "leaky_bucket_cache_key"
    setup_fake_store
    freeze_time
  end

  describe "#counter" do
    describe "when cache[@key] is nil" do
      it "returns the current bucket" do
        bucket_expected = { bucket: 0, last_updated: @time.to_i }
        Prop::LeakyBucketStrategy.counter(@key, interval: 1, threshold: 10).must_equal bucket_expected
      end
    end

    describe "when @store[@key] has an existing value" do
      before do
        Prop::Limiter.cache.write(@key, bucket: 100, last_updated: @time.to_i - 5)
      end

      it "returns the current bucket" do
        bucket_expected = { bucket: 50, last_updated: @time.to_i }
        Prop::LeakyBucketStrategy.counter(@key, interval: 1, threshold: 10).must_equal bucket_expected
      end
    end
  end

  describe "#change" do
    it "increments an empty bucket" do
      Prop::LeakyBucketStrategy.change(@key, increment: 5, interval: 1, threshold: 10)
      Prop::Limiter.cache.read(@key).must_equal bucket: 5, last_updated: @time.to_i
    end

    it "increments an existing bucket" do
      Prop::LeakyBucketStrategy.change(@key, increment: 5, interval: 1, threshold: 10)
      Prop::LeakyBucketStrategy.change(@key, increment: 5, interval: 1, threshold: 10)
      Prop::Limiter.cache.read(@key).must_equal bucket: 10, last_updated: @time.to_i
    end

    it "cannot decrement an empty bucket" do
      assert_raises ArgumentError do
        Prop::LeakyBucketStrategy.change(@key, decrement: 5)
      end
    end
  end

  describe "#reset" do
    before do
      Prop::Limiter.cache.write(@key, bucket: 100, last_updated: @time.to_i)
    end

    it "resets the bucket" do
      bucket_expected = { bucket: 0, last_updated: 0 }
      Prop::LeakyBucketStrategy.reset(@key)
      Prop::Limiter.cache.read(@key).must_equal bucket_expected
    end
  end

  describe "#compare_threshold?" do
    it "returns true when bucket is full" do
      assert Prop::LeakyBucketStrategy.compare_threshold?({ bucket: 100 }, :>=, { burst_rate: 100 })
      assert Prop::LeakyBucketStrategy.compare_threshold?({ bucket: 101 }, :>, { burst_rate: 100 })
    end

    it "returns false when bucket is not full" do
      refute Prop::LeakyBucketStrategy.compare_threshold?({ bucket: 99 }, :>=, { burst_rate: 100 })
      refute Prop::LeakyBucketStrategy.compare_threshold?({ bucket: 100 }, :>, { burst_rate: 100 })
    end
  end

  describe "#build" do
    it "returns a hexdigested key" do
      Prop::LeakyBucketStrategy.build(handle: :hello, key: [ "foo", 2, :bar ]).must_match(/prop\/leaky_bucket\/[a-f0-9]+/)
    end
  end

  describe "#validate_options!" do
    it "raise when burst rate is not valid" do
      @args = { threshold: 10, interval: 10, strategy: :leaky_bucket, burst_rate: 'five' }
      assert_raises(ArgumentError) { Prop::LeakyBucketStrategy.validate_options!(@args) }
    end
  end
end
