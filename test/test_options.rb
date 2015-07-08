require_relative 'helper'

describe Prop::Options do
  describe "#build" do
    before do
      @args = { :key => "hello", :params => { :foo => "bif" }, :defaults => { :foo => "bar", :baz => "moo", :threshold => 10, :interval => 5 }}
    end

    describe "when given valid input" do
      before do
        @options = Prop::Options.build(@args)
      end

      it "support defaults" do
        assert_equal "moo", @options[:baz]
      end

      it "override defaults" do
        assert_equal "bif", @options[:foo]
      end
    end

    describe "when given invalid input" do
      it "raise when not given an interval" do
        @args[:defaults].delete(:interval)
        assert_raises(ArgumentError) { Prop::Options.build(@args) }
      end

      it "raise when not given a threshold" do
        @args[:defaults].delete(:threshold)
        assert_raises(ArgumentError) { Prop::Options.build(@args) }
      end

      it "raise when not given a key" do
        @args.delete(:key)
        begin
          Prop::Options.build(@args)
          fail "it puke when not given a valid key"
        rescue
        end
      end

      it "raise when increment is not an positive Integer" do
        @args[:defaults].merge!(:increment => "one")
        assert_raises(ArgumentError) { Prop::Options.build(@args) }
      end
    end
  end
end
