require_relative 'helper'

describe Prop::Key do
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

