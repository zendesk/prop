require 'helper'

# Integration level tests
describe Prop do
  before do
    store = {}
    Prop.read  { |key| store[key] }
    Prop.write { |key, value| store[key] = value }

    @start = Time.now
    Time.stubs(:now).returns(@start)
  end

  describe "#defaults" do
    it "raise errors on invalid configuation" do
      assert_raises(RuntimeError) do
        Prop.configure :hello_there, :threshold => 20, :interval => 'hello'
      end

      assert_raises(RuntimeError) do
        Prop.configure :hello_there, :threshold => 'wibble', :interval => 100
      end
    end

    it "result in a default handle" do
      Prop.configure :hello_there, :threshold => 4, :interval => 10
      4.times do |i|
        assert_equal (i + 1), Prop.throttle!(:hello_there, 'some key')
      end

      assert_raises(Prop::RateLimited) { Prop.throttle!(:hello_there, 'some key') }
      assert_equal 5, Prop.throttle!(:hello_there, 'some key', :threshold => 20)
    end

    it "create a handle accepts various cache key types" do
      Prop.configure :hello_there, :threshold => 4, :interval => 10
      assert_equal 1, Prop.throttle!(:hello_there, 5)
      assert_equal 2, Prop.throttle!(:hello_there, 5)
      assert_equal 1, Prop.throttle!(:hello_there, '6')
      assert_equal 2, Prop.throttle!(:hello_there, '6')
      assert_equal 1, Prop.throttle!(:hello_there, [ 5, '6' ])
      assert_equal 2, Prop.throttle!(:hello_there, [ 5, '6' ])
    end
  end

  describe "#disable" do
    before do
      Prop.configure :hello, :threshold => 10, :interval => 10
    end

    it "not increase the throttle" do
      assert_equal 1, Prop.throttle!(:hello)
      assert_equal 2, Prop.throttle!(:hello)
      Prop.disabled do
        assert_equal 2, Prop.throttle!(:hello)
        assert_equal 2, Prop.throttle!(:hello)
        assert Prop::Limiter.send(:disabled?)
      end
      assert !Prop::Limiter.send(:disabled?)
      assert_equal 3, Prop.throttle!(:hello)
    end
  end

  describe "#reset" do
    before do
      Prop.configure :hello, :threshold => 10, :interval => 10

      5.times do |i|
        assert_equal (i + 1), Prop.throttle!(:hello)
      end
    end

    it "set the correct counter to 0" do
      Prop.throttle!(:hello, 'wibble')
      Prop.throttle!(:hello, 'wibble')

      Prop.reset(:hello)
      assert_equal 1, Prop.throttle!(:hello)

      assert_equal 3, Prop.throttle!(:hello, 'wibble')
      Prop.reset(:hello, 'wibble')
      assert_equal 1, Prop.throttle!(:hello, 'wibble')
    end
  end

  describe "#throttled?" do
    it "return true once the threshold has been reached" do
      Prop.configure(:hello, :threshold => 2, :interval => 10)
      Prop.throttle!(:hello)
      assert !Prop.throttled?(:hello)
      Prop.throttle!(:hello)
      assert Prop.throttled?(:hello)
    end
  end

  describe "#count" do
    before do
      Prop.configure(:hello, :threshold => 20, :interval => 20)
      Prop.throttle!(:hello)
      Prop.throttle!(:hello)
    end

    it "be aliased by #count" do
      assert_equal Prop.count(:hello), 2
    end

    it "return the number of hits on a throttle" do
      assert_equal Prop.query(:hello), 2
    end
  end

  describe "#throttle!" do
    it "increment counter correctly" do
      Prop.configure(:hello, :threshold => 20, :interval => 20)
      3.times do |i|
        assert_equal (i + 1), Prop.throttle!(:hello, nil, :threshold => 10, :interval => 10)
      end
    end

    it "reset counter when time window is passed" do
      Prop.configure(:hello, :threshold => 20, :interval => 20)
      3.times do |i|
        assert_equal (i + 1), Prop.throttle!(:hello, nil, :threshold => 10, :interval => 10)
      end

      Time.stubs(:now).returns(@start + 20)

      3.times do |i|
        assert_equal (i + 1), Prop.throttle!(:hello, nil, :threshold => 10, :interval => 10)
      end
    end

    it "not increment the counter beyond the threshold" do
      Prop.configure(:hello, :threshold => 5, :interval => 1)
      10.times do |i|
        Prop.throttle!(:hello) rescue nil
      end

      assert_equal 5, Prop.query(:hello)
    end

    it "support custom increments" do
      Prop.configure(:hello, :threshold => 100, :interval => 10)

      Prop.throttle!(:hello)
      Prop.throttle!(:hello)

      assert_equal 2, Prop.query(:hello)

      Prop.throttle!(:hello, nil, :increment => 48)

      assert_equal 50, Prop.query(:hello)
    end

    it "raise Prop::RateLimited when the threshold is exceeded" do
      Prop.configure(:hello, :threshold => 5, :interval => 10, :description => "Boom!")

      5.times do |i|
        Prop.throttle!(:hello, nil)
      end
      assert_raises(Prop::RateLimited) do
        Prop.throttle!(:hello, nil)
      end

      begin
        Prop.throttle!(:hello, nil)
        fail
      rescue Prop::RateLimited => e
        assert_equal :hello, e.handle
        assert_match "5 tries per 10s exceeded for key", e.message
        assert_equal "Boom!", e.description
        assert e.retry_after
      end
    end

    it "raise a RuntimeError when a handle has not been configured" do
      assert_raises(RuntimeError) do
        Prop.throttle!(:no_such_handle, nil, :threshold => 5, :interval => 10)
      end
    end
  end

  describe 'different handles with the same interval' do
    before do
      Prop.configure(:api_requests, :threshold => 100, :interval => 30)
      Prop.configure(:login_attempts, :threshold => 10, :interval => 30)
    end

    it 'be counted separately' do
      user_id = 42
      Prop.throttle!(:api_requests, user_id)
      assert_equal(1, Prop.count(:api_requests, user_id))
      assert_equal(0, Prop.count(:login_attempts, user_id))
    end
  end

  describe "#configurations" do
    it "returns the configuration" do
      Prop.configure(:something, :threshold => 100, :interval => 30)
      config = Prop.configurations[:something]
      assert_equal 100, config[:threshold]
      assert_equal 30, config[:interval]
    end
  end
end
