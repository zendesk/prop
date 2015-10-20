require 'bundler/setup'

require "maxitest/autorun"
require 'mocha/setup'

require 'time'
require 'prop'

Minitest::Test.class_eval do
  def setup_fake_store
    store = {}
    Prop.read { |key| store[key] }
    Prop.write { |key, value| store[key] = value }
  end

  def freeze_time
    @start = Time.now
    Time.stubs(:now).returns(@start)
  end
end
