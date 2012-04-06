require 'helper'

class TestKey < Test::Unit::TestCase

  context Prop::Key do
    context "#build" do
      should "return a hexdigested key" do
        assert_match /prop\/[a-f0-9]+/, Prop::Key.build(:handle => :hello, :key => [ "foo", 2, :bar ], :interval => 60)
      end
    end

    context "#normalize" do
      should "turn a Fixnum into a String" do
        assert_equal "3", Prop::Key.normalize(3)
      end

      should "return a String" do
        assert_equal "S", Prop::Key.normalize("S")
      end

      should "flatten and join an Array" do
        assert_equal "1/B/3", Prop::Key.normalize([ 1, "B", "3" ])
      end
    end
  end
end