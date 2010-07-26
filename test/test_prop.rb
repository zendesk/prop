require 'helper'

class TestProp < Test::Unit::TestCase

  context "Prop" do
    setup do
      store = {}
      Prop.read  { |key| store[key] }
      Prop.write { |key, value| store[key] = value }

      @start = Time.now
      Time.stubs(:now).returns(@start)
    end

    context "#configure" do
      should "raise errors on invalid configuation" do
        assert_raises(RuntimeError) do
          Prop.setup :hello_there, :threshold => 20, :interval => 'hello'
        end

        assert_raises(RuntimeError) do
          Prop.setup :hello_there, :threshold => 'wibble', :interval => 100
        end
      end

      should "accept a handle and an options hash" do
        Prop.setup :hello_there, :threshold => 40, :interval => 100
        assert Prop.respond_to?(:throttle_hello_there!)
        assert Prop.respond_to?(:throttle_hello_there?)
        assert Prop.respond_to?(:reset_hello_there)
      end

      should "result in a default handle" do
        Prop.setup :hello_there, :threshold => 4, :interval => 10
        4.times do |i|
          assert_equal (i + 1), Prop.throttle_hello_there!('some key')
        end

        assert_raises(Prop::RateLimitExceededError) { Prop.throttle_hello_there!('some key') }
        assert_equal 5, Prop.throttle_hello_there!('some key', :threshold => 20)
      end

      should "create a handle accepts various cache key types" do
        Prop.setup :hello_there, :threshold => 4, :interval => 10
        assert_equal 1, Prop.throttle_hello_there!(5)
        assert_equal 2, Prop.throttle_hello_there!(5)
        assert_equal 1, Prop.throttle_hello_there!('mister')
        assert_equal 2, Prop.throttle_hello_there!('mister')
        assert_equal 1, Prop.throttle_hello_there!('mister', 5)
        assert_equal 2, Prop.throttle_hello_there!('mister', 5)
      end

      should "not shadow undefined methods" do
        assert_raises(NoMethodError) { Prop.no_such_handle }
      end
    end

    context "#reset" do
      setup do
        Prop.setup :hello, :threshold => 10, :interval => 10

        5.times do |i|
          assert_equal (i + 1), Prop.throttle_hello!
        end
      end

      should "set the correct counter to 0" do
        Prop.throttle_hello!('wibble')
        Prop.throttle_hello!('wibble')

        Prop.reset_hello
        assert_equal 1, Prop.throttle_hello!

        assert_equal 3, Prop.throttle_hello!('wibble')
        Prop.reset_hello('wibble')
        assert_equal 1, Prop.throttle_hello!('wibble')
      end

      should "be directly invokable" do
        Prop.reset :key => :hello, :threshold => 10, :interval => 10
        assert_equal 1, Prop.throttle_hello!
      end
    end

    context "#throttle?" do
      should "return true once the threshold has been reached" do
        Prop.throttle!(:key => 'hello', :threshold => 2, :interval => 10)
        assert !Prop.throttle?(:key => 'hello', :threshold => 2, :interval => 10)

        Prop.throttle!(:key => 'hello', :threshold => 2, :interval => 10)
        assert Prop.throttle?(:key => 'hello', :threshold => 2, :interval => 10)
      end
    end

    context "#throttle!" do
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

      should "not reset counter when violations happen during the time window for a progressive cache" do
        start = Time.parse("2006-05-04 03:02:01")
        Time.stubs(:now).returns(start)

        Prop.setup :not_progressive, :threshold => 5, :interval => 10

        assert_raises(Prop::RateLimitExceededError) do
          6.times { Prop.throttle_not_progressive! }
        end

        Time.stubs(:now).returns(start + 5)
        assert_raises(Prop::RateLimitExceededError) { Prop.throttle_not_progressive! }
        Time.stubs(:now).returns(start + 15)
        assert Prop.throttle_not_progressive!

        Time.stubs(:now).returns(start)
        Prop.setup :progressive, :threshold => 5, :interval => 10, :progressive => true

        assert_raises(Prop::RateLimitExceededError) do
          6.times { Prop.throttle_progressive! }
        end

        Time.stubs(:now).returns(start + 5)
        assert_raises(Prop::RateLimitExceededError) { Prop.throttle_progressive! }

        Time.stubs(:now).returns(start + 11)
        assert_raises(Prop::RateLimitExceededError) { Prop.throttle_progressive! }
      end

      should "not increment the counter beyon the threshold" do
        10.times do |i|
          Prop.throttle!(:key => 'hello', :threshold => 5, :interval => 10) rescue nil
        end

        assert_equal 5, Prop.count(:key => 'hello', :threshold => 5, :interval => 10)
      end

      should "raise Prop::RateLimitExceededError when the threshold is exceeded" do
        5.times do |i|
          Prop.throttle!(:key => 'hello', :threshold => 5, :interval => 10)
        end
        assert_raises(Prop::RateLimitExceededError) do
          Prop.throttle!(:key => 'hello', :threshold => 5, :interval => 10)
        end

        begin
          Prop.throttle!(:key => 'hello', :threshold => 5, :interval => 10, :message => "Wibble")
          fail
        rescue Prop::RateLimitExceededError => e
          assert_equal "Wibble", e.message
          assert_equal "hello threshold 5 exceeded", e.root_message
          assert e.retry_after
        end
      end
    end

  end
end
