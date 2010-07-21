require 'helper'

class TestProp < Test::Unit::TestCase

  context "Prop" do
    setup do
      store = {}
      Prop.read  { |key| store[key] }
      Prop.write { |key, value| store[key] = value }
    end

    context "#configure" do
      should "raise errors on invalid configuation" do
        assert_raises(RuntimeError) do
          Prop.configure :hello_there, :threshold => 20, :interval => 'hello'
        end

        assert_raises(RuntimeError) do
          Prop.configure :hello_there, :threshold => 'wibble', :interval => 100
        end
      end

      should "accept a handle and an options hash" do
        Prop.configure :hello_there, :threshold => 40, :interval => 100
        assert Prop.handles
        assert_equal Prop.handles.keys.first, :hello_there
        assert_equal Prop.handles.values.first, { :threshold => 40, :interval => 100 }
        assert Prop.hello_there
      end
    end
    
    context "#throttle!" do
      setup do
        @start = Time.now
        Time.stubs(:now).returns(@start)
      end

      should "increment counter correctly" do
        3.times do |i|
          assert_equal (i + 1), Prop.throttle!(:key => 'hello', :threshold => 10, :interval => 10)
        end
      end

      should "reset counter when time window is passed" do
        3.times do |i|
          assert_equal (i + 1), Prop.throttle!(:key => 'hello', :threshold => 10, :interval => 10)
        end

        Time.stubs(:now).returns(@start + 20)

        3.times do |i|
          assert_equal (i + 1), Prop.throttle!(:key => 'hello', :threshold => 10, :interval => 10)
        end
      end
      
      should "raise Prop::RateLimitExceededError when the threshold is exceeded" do
        5.times do |i|
          Prop.throttle!(:key => 'hello', :threshold => 5, :interval => 10)
        end
        assert_raises(Prop::RateLimitExceededError) do
          puts Prop.throttle!(:key => 'hello', :threshold => 5, :interval => 10)
        end
      end
    end
  end
end
