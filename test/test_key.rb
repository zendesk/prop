# frozen_string_literal: true
require_relative 'helper'

describe Prop::Key do
  describe "#normalize" do
    it "turn a Integer into a String" do
      Prop::Key.normalize(3).must_equal "3"
    end

    it "return a String" do
      Prop::Key.normalize("S").must_equal "S"
    end

    it "flatten and join an Array" do
      Prop::Key.normalize([ 1, "B", "3" ]).must_equal "1/B/3"
    end
  end
end

