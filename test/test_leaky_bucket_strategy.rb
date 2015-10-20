require_relative 'helper'

describe Prop::LeakyBucketStrategy do
  before do
    @store = {}
    @key = "leaky_bucket_cache_key"

    Prop::Limiter.read  { |key| @store[key] }
    Prop::Limiter.write { |key, value| @store[key] = value }

    @time = Time.now
    Time.stubs(:now).returns(@time)
  end

  describe "#update_bucket" do
    before do
      @store[@key] = { bucket: 100, last_updated: @time.to_i - 10 }
    end

    it "should update the bucket" do
      bucket_expected = { bucket: 0, last_updated: @time.to_i }
      Prop::LeakyBucketStrategy.update_bucket(@key, 1, 10)
      @store[@key].must_equal bucket_expected
    end
  end

  describe "#counter" do
    describe "when @store[@key] is nil" do
      it "returns the current bucket" do
        bucket_expected = { bucket: 0, last_updated: @time.to_i, burst_rate: nil }
        Prop::LeakyBucketStrategy.counter(@key, interval: 1, threshold: 10).must_equal bucket_expected
      end
    end

    describe "when @store[@key] has an existing value" do
      before do
        @store[@key] = { bucket: 100, last_updated: @time.to_i - 5 }
      end

      it "returns the current bucket" do
        bucket_expected = { bucket: 50, last_updated: @time.to_i, burst_rate: nil }
        Prop::LeakyBucketStrategy.counter(@key, interval: 1, threshold: 10).must_equal bucket_expected
      end
    end
  end

  describe "#increment" do
     it "increments the bucket" do
       bucket_expected = { bucket: 6, last_updated: @time.to_i }
       Prop::LeakyBucketStrategy.increment(@key, { increment: 5 }, bucket: 1)
       Prop::Limiter.reader.call(@key).must_equal bucket_expected
     end
  end

  describe "#reset" do
    before do
      @store[@key] = { bucket: 100, last_updated: @time.to_i }
    end

    it "resets the bucket" do
      bucket_expected = { bucket: 0, last_updated: 0 }
      Prop::LeakyBucketStrategy.reset(@key)
      Prop::Limiter.reader.call(@key).must_equal bucket_expected
    end
  end

  describe "#at_threshold?" do
    it "returns true when bucket is full" do
      assert Prop::LeakyBucketStrategy.at_threshold?({ bucket: 100 }, { burst_rate: 100 })
    end

    it "returns false when bucket is not full" do
      refute Prop::LeakyBucketStrategy.at_threshold?({ bucket: 99 }, { burst_rate: 100 })
    end
  end

  describe "#build" do
    it "returns a hexdigested key" do
      Prop::LeakyBucketStrategy.build(handle: :hello, key: [ "foo", 2, :bar ]).must_match /prop\/leaky_bucket\/[a-f0-9]+/
    end
  end

  describe "#validate_options!" do
    it "raise when burst rate is not valid" do
      @args = { threshold: 10, interval: 10, strategy: :leaky_bucket, burst_rate: 'five' }
      assert_raises(ArgumentError) { Prop::LeakyBucketStrategy.validate_options!(@args) }
    end
  end
end
