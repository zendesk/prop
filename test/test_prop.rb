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

    context "#defaults" do
      should "raise errors on invalid configuation" do
        assert_raises(RuntimeError) do
          Prop.configure :hello_there, :threshold => 20, :interval => 'hello'
        end

        assert_raises(RuntimeError) do
          Prop.configure :hello_there, :threshold => 'wibble', :interval => 100
        end
      end

      should "result in a default handle" do
        Prop.configure :hello_there, :threshold => 4, :interval => 10
        4.times do |i|
          assert_equal (i + 1), Prop.throttle!(:hello_there, 'some key')
        end

        assert_raises(Prop::RateLimitExceededError) { Prop.throttle!(:hello_there, 'some key') }
        assert_equal 5, Prop.throttle!(:hello_there, 'some key', :threshold => 20)
      end

      should "create a handle accepts various cache key types" do
        Prop.configure :hello_there, :threshold => 4, :interval => 10
        assert_equal 1, Prop.throttle!(:hello_there, 5)
        assert_equal 2, Prop.throttle!(:hello_there, 5)
        assert_equal 1, Prop.throttle!(:hello_there, '6')
        assert_equal 2, Prop.throttle!(:hello_there, '6')
        assert_equal 1, Prop.throttle!(:hello_there, [ 5, '6' ])
        assert_equal 2, Prop.throttle!(:hello_there, [ 5, '6' ])
      end
    end

    context "#disable" do
      setup do
        Prop.configure :hello, :threshold => 10, :interval => 10
      end

      should "not increase the throttle" do
        assert_equal 1, Prop.throttle!(:hello)
        assert_equal 2, Prop.throttle!(:hello)
        Prop.disabled do
          assert_equal 2, Prop.throttle!(:hello)
          assert_equal 2, Prop.throttle!(:hello)
          assert Prop.disabled?
        end
        assert !Prop.disabled?
        assert_equal 3, Prop.throttle!(:hello)
      end
    end

    context "#reset" do
      setup do
        Prop.configure :hello, :threshold => 10, :interval => 10

        5.times do |i|
          assert_equal (i + 1), Prop.throttle!(:hello)
        end
      end

      should "set the correct counter to 0" do
        Prop.throttle!(:hello, 'wibble')
        Prop.throttle!(:hello, 'wibble')

        Prop.reset(:hello)
        assert_equal 1, Prop.throttle!(:hello)

        assert_equal 3, Prop.throttle!(:hello, 'wibble')
        Prop.reset(:hello, 'wibble')
        assert_equal 1, Prop.throttle!(:hello, 'wibble')
      end
    end

    context "#throttled?" do
      should "return true once the threshold has been reached" do
        Prop.configure(:hello, :threshold => 2, :interval => 10)
        Prop.throttle!(:hello)
        assert !Prop.throttled?(:hello)
        Prop.throttle!(:hello)
        assert Prop.throttled?(:hello)
      end
    end

    context "#query" do
      setup do
        Prop.configure(:hello, :threshold => 20, :interval => 20)
        Prop.throttle!(:hello)
        Prop.throttle!(:hello)
      end

      should "be aliased by #count" do
        assert_equal Prop.count(:hello), 2
      end

      should "return the number of hits on a throttle" do
        assert_equal Prop.query(:hello), 2
      end
    end

    context "#throttle!" do
      should "increment counter correctly" do
        3.times do |i|
          assert_equal (i + 1), Prop.throttle!(:hello, nil, :threshold => 10, :interval => 10)
        end
      end

      should "reset counter when time window is passed" do
        3.times do |i|
          assert_equal (i + 1), Prop.throttle!(:hello, nil, :threshold => 10, :interval => 10)
        end

        Time.stubs(:now).returns(@start + 20)

        3.times do |i|
          assert_equal (i + 1), Prop.throttle!(:hello, nil, :threshold => 10, :interval => 10)
        end
      end

      should "not increment the counter beyond the threshold" do
        Prop.configure(:hello, :threshold => 5, :interval => 1)
        10.times do |i|
          Prop.throttle!(:hello) rescue nil
        end

        assert_equal 5, Prop.query(:hello)
      end

      should "support custom increments" do
        Prop.configure(:hello, :threshold => 100, :interval => 10)

        Prop.throttle!(:hello)
        Prop.throttle!(:hello)

        assert_equal 2, Prop.query(:hello)

        Prop.throttle!(:hello, nil, :increment => 48)

        assert_equal 50, Prop.query(:hello)
      end

      should "raise Prop::RateLimitExceededError when the threshold is exceeded" do
        5.times do |i|
          Prop.throttle!(:hello, nil, :threshold => 5, :interval => 10)
        end
        assert_raises(Prop::RateLimitExceededError) do
          Prop.throttle!(:hello, nil, :threshold => 5, :interval => 10)
        end

        begin
          Prop.throttle!(:hello, nil, :threshold => 5, :interval => 10, :description => "Boom!")
          fail
        rescue Prop::RateLimitExceededError => e
          assert_equal :hello, e.handle
          assert_equal "hello threshold of 5 exceeded for key ''", e.message
          assert_equal "Boom!", e.description
          assert e.retry_after
        end
      end

      should "raise a RuntimeError when a handle has not been configured" do
        assert_raises(RuntimeError) do
          Prop.throttle!(:no_such_handle, nil, :threshold => 5, :interval => 10)
        end
      end
    end

  end
end
