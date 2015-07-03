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
      @store[@key] = { :bucket => 100, :last_updated => @time.to_i - 10 }
    end

    it "should update the bucket" do
      bucket_expected = { :bucket => 0, :last_updated => @time.to_i }
      Prop::LeakyBucketStrategy.update_bucket(@key, 1, 10)
      assert_equal bucket_expected, @store[@key]
    end
  end

  describe "#counter" do
    before do
      @store[@key] = { :bucket => 100, :last_updated => @time.to_i - 5 }
    end

    it "returns the current bucket" do
      bucket_expected = { :bucket => 50, :last_updated => @time.to_i, :burst_rate => nil }
      assert_equal bucket_expected, Prop::LeakyBucketStrategy.counter(@key, :interval => 1, :threshold =>10)
    end
  end

  describe "#increment" do
     it "increments the bucket" do
       bucket_expected = { :bucket => 6, :last_updated => @time.to_i }
       assert_equal bucket_expected, Prop::LeakyBucketStrategy.increment(@key, { :increment => 5 }, :bucket => 1)
     end
  end

  describe "#reset" do
    before do
      @store[@key] = { :bucket => 100, :last_updated => @time.to_i }
    end

    it "resets the bucket" do
      bucket_expected = { :bucket => 0, :last_updated => 0 }
      assert_equal bucket_expected, Prop::LeakyBucketStrategy.reset(@key)
    end
  end

  describe "#at_threshold?" do
    it "returns true when bucket is full" do
      assert Prop::LeakyBucketStrategy.at_threshold?({ :bucket => 100 }, { :burst_rate => 100 })
    end

    it "returns false when bucket is not full" do
      assert !Prop::LeakyBucketStrategy.at_threshold?({ :bucket => 99 }, { :burst_rate => 100 })
    end
  end

  describe "#build" do
    it "returns a hexdigested key" do
      assert_match /prop\/leaky_bucket\/[a-f0-9]+/, Prop::LeakyBucketStrategy.build(:handle => :hello, :key => [ "foo", 2, :bar ])
    end
  end
end
