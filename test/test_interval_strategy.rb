# frozen_string_literal: true
require_relative 'helper'

describe Prop::IntervalStrategy do
  before do
    @key = "cache_key"
    setup_fake_store
    freeze_time
  end

  describe "#counter" do
    describe "when @store[@key] is nil" do
      it "returns the current count" do
        Prop::IntervalStrategy.counter(@key, nil).must_equal 0
      end
    end

    describe "when @store[@key] has an existing value" do
      before { Prop::Limiter.cache.write(@key, 1) }

      it "returns the current count" do
        Prop::IntervalStrategy.counter(@key, nil).must_equal 1
      end
    end
  end

  describe "#increment" do
    it "increments an empty bucket" do
      Prop::IntervalStrategy.increment(@key, 5)
      assert_equal 5, Prop::IntervalStrategy.counter(@key, nil)
    end

    it "increments a filled bucket" do
      Prop::IntervalStrategy.increment(@key, 5)
      Prop::IntervalStrategy.increment(@key, 5)
      assert_equal 10, Prop::IntervalStrategy.counter(@key, nil)
    end

    it "does not write non-integers" do
      assert_raises ArgumentError do
        Prop::IntervalStrategy.increment(@key, "WHOOPS")
      end
    end
  end

  describe "#decrement" do
    xit "returns 0 when decrements an empty bucket" do
      Prop::IntervalStrategy.decrement(@key, -5)
      assert_equal 0, Prop::IntervalStrategy.counter(@key, nil)
    end

    it "decrements a filled bucket" do
      Prop::IntervalStrategy.increment(@key, 5)
      Prop::IntervalStrategy.decrement(@key, 2)
      assert_equal 3, Prop::IntervalStrategy.counter(@key, nil)
    end

    it "does not write non-integers" do
      assert_raises ArgumentError do
        Prop::IntervalStrategy.decrement(@key, "WHOOPS")
      end
    end
  end

  describe "#reset" do
    before { Prop::Limiter.cache.write(@key, 100) }

    it "resets the bucket" do
      Prop::IntervalStrategy.reset(@key)
      Prop::IntervalStrategy.counter(@key, nil).must_equal 0
    end
  end

  describe "#compare_threshold?" do
    it "returns true when the limit has been reached" do
      assert Prop::IntervalStrategy.compare_threshold?(100, :>=, { threshold: 100 })
      assert Prop::IntervalStrategy.compare_threshold?(101, :>, { threshold: 100 })
    end

    it "returns false when the limit has not been reached" do
      refute Prop::IntervalStrategy.compare_threshold?(99, :>=, { threshold: 100 })
      refute Prop::IntervalStrategy.compare_threshold?(100, :>, { threshold: 100 })
    end

    it "returns false when the counter fails to increment" do
      refute Prop::IntervalStrategy.compare_threshold?(false, :>, { threshold: 100 })
      refute Prop::IntervalStrategy.compare_threshold?(nil, :>, { threshold: 100 })
    end
  end

  describe "#build" do
    it "returns a hexdigested key" do
      Prop::IntervalStrategy.build(handle: :hello, key: [ "foo", 2, :bar ], interval: 60).must_match(/prop\/v2\/[a-f0-9]+/)
    end
  end

  describe "#validate_options!" do
    describe "when :increment is zero" do
      it "does not raise exception" do
        arg = { threshold: 1, interval: 1, increment: 0}
        refute Prop::IntervalStrategy.validate_options!(arg)
      end
    end

    describe "when :threshold is set to zero to disable the prop" do
      it "does not raise exception" do
        arg = { threshold: 0, interval: 1, increment: 1}
        refute Prop::IntervalStrategy.validate_options!(arg)
      end
    end
  end
end
