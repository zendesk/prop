require 'helper'

class TestOptions < Test::Unit::TestCase

  context Prop::Options do
    context "#build" do
      setup do
        @args = { :key => "hello", :params => { :foo => "bif" }, :defaults => { :foo => "bar", :baz => "moo", :threshold => 10, :interval => 5 }}
      end

      context "when given valid input" do
        setup do
          @options = Prop::Options.build(@args)
        end

        should "support defaults" do
          assert_equal "moo", @options[:baz]
        end

        should "override defaults" do
          assert_equal "bif", @options[:foo]
        end
      end

      context "when given invalid input" do
        should "raise when not given an interval" do
          @args[:defaults].delete(:interval)
          assert_raises(RuntimeError) { Prop::Options.build(@args) }
        end

        should "raise when not given a threshold" do
          @args[:defaults].delete(:threshold)
          assert_raises(RuntimeError) { Prop::Options.build(@args) }
        end

        should "raise when not given a key" do
          @args.delete(:key)
          begin
            Prop::Options.build(@args)
            fail "Should puke when not given a valid key"
          rescue
          end
        end
      end
    end

  end
end