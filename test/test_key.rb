require_relative 'helper'

describe Prop::Key do
  describe "#build" do
    it "returns a hexdigested key" do
      options = { :handle => :hello, :key => [ "foo", 2, :bar ], :interval => 60 }
      assert_match /prop\/[a-f0-9]+/, Prop::Key.build(Prop::IntervalStrategy, options)
    end
  end

  describe "#normalize" do
    it "turn a Fixnum into a String" do
      assert_equal "3", Prop::Key.normalize(3)
    end

    it "return a String" do
      assert_equal "S", Prop::Key.normalize("S")
    end

    it "flatten and join an Array" do
      assert_equal "1/B/3", Prop::Key.normalize([ 1, "B", "3" ])
    end
  end
end

