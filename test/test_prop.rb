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

      should "result in a default handle" do
        Prop.configure :hello_there, :threshold => 4, :interval => 10
        4.times do |i|
          assert_equal (i + 1), Prop.hello_there('some key')
        end

        assert_raises(Prop::RateLimitExceededError) { Prop.hello_there('some key') }

        assert_equal 5, Prop.hello_there('some key', :threshold => 20)
      end

      should "create a handle accepts integer keys" do
        Prop.configure :hello_there, :threshold => 4, :interval => 10
        assert Prop.hello_there(5)
      end

      should "not shadow undefined methods" do
        assert_raises(NoMethodError) { Prop.no_such_handle }
      end
    end

    context "#reset" do
      setup do
        @start = Time.now
        Time.stubs(:now).returns(@start)
        Prop.configure :hello, :threshold => 10, :interval => 10

        5.times do |i|
          assert_equal (i + 1), Prop.hello
        end
      end

      should "set the correct counter to 0" do
        Prop.hello('wibble')
        Prop.hello('wibble')

        Prop.reset_hello
        assert_equal 1, Prop.hello

        assert_equal 3, Prop.hello('wibble')
        Prop.reset_hello('wibble')
        assert_equal 1, Prop.hello('wibble')
      end

      should "be directly invokable" do
        Prop.reset(:key => :hello, :threshold => 10, :interval => 10)
        assert_equal 1, Prop.hello
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
          Prop.throttle!(:key => 'hello', :threshold => 5, :interval => 10)
        end
      end
    end

  end
end
