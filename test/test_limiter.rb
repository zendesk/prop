require 'helper'


describe Prop::Limiter do
  before do
    @store = {}

    Prop::Limiter.read  { |key| @store[key] }
    Prop::Limiter.write { |key, value| @store[key] = value }
    Prop::Limiter.configure(:something, :threshold => 10, :interval => 10)

    @start = Time.now
    Time.stubs(:now).returns(@start)
  end

  describe "#throttle!" do
    before do
      Prop.reset(:something)
    end

    describe "when disabled" do
      before { Prop::Limiter.expects(:disabled?).returns(true) }

      [ true, false ].each do |threshold_reached|
        describe "and threshold has #{"not " unless threshold_reached}been reached" do
          before { Prop::Limiter.stubs(:at_threshold?).returns(threshold_reached) }

          describe "given a block" do
            it "execute that block" do
              assert_equal "wibble", Prop.throttle!(:something) { "wibble" }
            end
          end

          describe "not given a block" do
            it "return the current throttle count" do
              assert_equal Prop.count(:something), Prop.throttle!(:something)
            end
          end
        end
      end
    end

    describe "when not disabled" do
      before { Prop::Limiter.expects(:disabled?).returns(false) }

      describe "and threshold has been reached" do
        before { Prop::Limiter.expects(:at_threshold?).returns(true) }

        describe "given a block" do
          it "raise Prop::RateLimited" do
            assert_raises(Prop::RateLimited) { Prop.throttle!(:something) { "wibble" }}
          end

          it "raise even if given :increment => 0" do
            value = Prop.count(:something)
            assert_raises(Prop::RateLimited) { Prop.throttle!(:something, nil, :increment => 0) { "wibble" }}
            assert_equal value, Prop.count(:something)
          end
        end

        describe "not given a block" do
          it "raise Prop::RateLimited" do
            assert_raises(Prop::RateLimited) { Prop.throttle!(:something) }
          end
        end
      end

      describe "and threshold has not been reached" do
        before do
          Prop::Limiter.expects(:at_threshold?).returns(false)
        end

        describe "given a block" do
          it "execute that block" do
            assert_equal "wibble", Prop.throttle!(:something) { "wibble" }
          end
        end

        describe "not given a block" do
          it "return the updated throttle count" do
            assert_equal Prop.count(:something) + 1, Prop.throttle!(:something)
          end

          it "not update count if passed an increment of 0" do
            assert_equal Prop.count(:something), Prop.throttle!(:something, nil, :increment => 0)
          end
        end
      end
    end
  end
end
