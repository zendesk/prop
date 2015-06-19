require_relative 'helper'

describe LeakyBucket::Bucket do
  before do
    @store = {}
    @key = "leaky_bucket_cache_key"

    Prop::Limiter.read  { |key| @store[key] }
    Prop::Limiter.write { |key, value| @store[key] = value }
    Prop::Limiter.configure(:something, :threshold => 10, :interval => 1, :burst_rate => 100)
    Prop::Key.stubs(:build_bucket_key).returns(@key)

    LeakyBucket::Bucket.reset_bucket(:something)

    @time = Time.now
    Time.stubs(:now).returns(@time)
  end

  describe "#update_bucket" do
    before do
      @store[@key] = { :bucket => 100, :last_updated => @time.to_i - 10 }
    end

    it "should update the bucket" do
      bucket_expected = { :bucket => 0, :last_updated => @time.to_i }
      LeakyBucket::Bucket.update_bucket(@key, 1, 10)
      assert_equal bucket_expected, @store[@key]
    end
  end

  describe "#leaky" do
    describe "when the bucket is not full" do
      it "increments the count number and saves timestamp in the bucket" do
        bucket_expected = { :bucket => 1, :last_updated => @time.to_i }
        assert !LeakyBucket::Bucket.leaky(:something)
        assert_equal bucket_expected, @store[@key]
      end
    end

    describe "when the bucket is full" do
      before do
        @store[@key] = { :bucket => 100, :last_updated => @time.to_i }
      end

      it "returns true and doesn't increment the count number in the bucket" do
        bucket_expected = { :bucket => 100, :last_updated => @time.to_i }
        assert LeakyBucket::Bucket.leaky(:something)
        assert_equal bucket_expected, @store[@key]
      end
    end
  end

  describe "#leaky!" do
    it "throttles the given handle/key combination" do
      LeakyBucket::Bucket.expects(:leaky).with(
        :something,
        :key,
        {
          :threshold  => 10,
          :interval   => 1,
          :key        => 'key',
          :burst_rate => 100,
          :options    => true
        }
      )

      LeakyBucket::Bucket.leaky!(:something, :key, :options => true)
    end

    describe "when the bucket is full" do
      before do
        LeakyBucket::Bucket.expects(:leaky).returns(true)
      end

      it "raises RateLimited exception" do
        assert_raises Prop::RateLimited do
          LeakyBucket::Bucket.leaky!(:something)
        end
      end
    end

    describe "when the bucket is not full" do
      it "returns the counter value in the bucket" do
        assert_equal 1, LeakyBucket::Bucket.leaky!(:something)
      end
    end
  end
end
