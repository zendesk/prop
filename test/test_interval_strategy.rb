require_relative 'helper'

describe Prop::IntervalStrategy do
  before do
    @store = {}
    @key = "cache_key"

    Prop::Limiter.read  { |key| @store[key] }
    Prop::Limiter.write { |key, value| @store[key] = value }

    @time = Time.now
    Time.stubs(:now).returns(@time)
  end

  describe "#counter" do
    describe "when @store[@key] is nil" do
      it "returns the current count" do
        assert_equal 0, Prop::IntervalStrategy.counter(@key, nil)
      end
    end

    describe "when @store[@key] has an existing value" do
      before { @store[@key] = 1 }

      it "returns the current count" do
        assert_equal 1, Prop::IntervalStrategy.counter(@key, nil)
      end
    end
  end

  describe "#increment" do
    it "increments the bucket" do
      Prop::IntervalStrategy.increment(@key, { :increment => 5 }, 1)
      assert_equal 6, Prop::IntervalStrategy.counter(@key, nil)
    end
  end

  describe "#reset" do
    before { @store[@key] = 100 }

    it "resets the bucket" do
      Prop::IntervalStrategy.reset(@key)
      assert_equal 0, Prop::IntervalStrategy.counter(@key, nil)
    end
  end

  describe "#at_threshold?" do
    it "returns true when the limit has been reached" do
      assert Prop::IntervalStrategy.at_threshold?(100, { :threshold => 100 })
    end

    it "returns false when the limit has not been reached" do
      assert !Prop::IntervalStrategy.at_threshold?(99, { :threshold => 100 })
    end
  end

  describe "#build" do
    it "returns a hexdigested key" do
      assert_match /prop\/[a-f0-9]+/, Prop::IntervalStrategy.build(:handle => :hello, :key => [ "foo", 2, :bar ], :interval => 60)
    end
  end

  describe "#validate_options!" do
    describe "when :increment is zero" do
      it "does not raise exception" do
        arg = { :threshold => 1, :interval => 1, :increment => 0}
        assert_nil Prop::IntervalStrategy.validate_options!(arg)
      end
    end
  end
end
