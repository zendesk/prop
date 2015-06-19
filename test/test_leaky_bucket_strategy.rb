require_relative 'helper'

describe Prop::LeakyBucketStrategy do
  before do
    @store = {}
    @key = "leaky_bucket_cache_key"

    Prop::Limiter.read  { |key| @store[key] }
    Prop::Limiter.write { |key, value| @store[key] = value }
    Prop::Limiter.configure(:something, :threshold => 10, :interval => 1, :burst_rate => 100, :leaky_bucket => true)
    Prop::Key.stubs(:build_bucket_key).returns(@key)

    Prop::Limiter.reset(:something)

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
end
