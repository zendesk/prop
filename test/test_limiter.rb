require 'helper'

class TestLimiter < Test::Unit::TestCase

  context Prop::Limiter do
    setup do
      @store = {}

      Prop::Limiter.read  { |key| @store[key] }
      Prop::Limiter.write { |key, value| @store[key] = value }
      Prop::Limiter.configure(:something, :threshold => 10, :interval => 10)

      @start = Time.now
      Time.stubs(:now).returns(@start)
    end

    context "#throttle!" do
      setup do
        Prop.reset(:something)
      end

      context "when disabled" do
        setup { Prop::Limiter.expects(:disabled?).returns(true) }

        [ true, false ].each do |threshold_reached|
          context "and threshold has #{"not " unless threshold_reached}been reached" do
            setup { Prop::Limiter.stubs(:at_threshold?).returns(threshold_reached) }

            context "given a block" do
              should "execute that block" do
                assert_equal "wibble", Prop.throttle!(:something) { "wibble" }
              end
            end

            context "not given a block" do
              should "return the current throttle count" do
                assert_equal Prop.count(:something), Prop.throttle!(:something)
              end
            end
          end
        end
      end

      context "when not disabled" do
        setup { Prop::Limiter.expects(:disabled?).returns(false) }

        context "and threshold has been reached" do
          setup { Prop::Limiter.expects(:at_threshold?).returns(true) }

          context "given a block" do
            should "raise Prop::RateLimited" do
              assert_raises(Prop::RateLimited) { Prop.throttle!(:something) { "wibble" }}
            end
          end

          context "not given a block" do
            should "raise Prop::RateLimited" do
              assert_raises(Prop::RateLimited) { Prop.throttle!(:something) }
            end
          end
        end

        context "and threshold has not been reached" do
          setup do
            Prop::Limiter.expects(:at_threshold?).returns(false)
          end

          context "given a block" do
            should "execute that block" do
              assert_equal "wibble", Prop.throttle!(:something) { "wibble" }
            end
          end

          context "not given a block" do
            should "return the updated throttle count" do
              assert_equal Prop.count(:something) + 1, Prop.throttle!(:something)
            end
          end
        end
      end
    end
  end
end
