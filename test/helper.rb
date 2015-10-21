require 'bundler/setup'

require "maxitest/autorun"
require 'mocha/setup'

require 'time'
require 'prop'

class MemoryStore
  def initialize
    @store = {}
  end

  def read(key)
    @store[key]
  end

  def write(key, value)
    @store[key] = value
  end

  # simulate memcached increment behavior
  def increment(key, value)
    @store[key] += value if @store[key]
  end
end

Minitest::Test.class_eval do
  def setup_fake_store
    Prop.cache = MemoryStore.new
  end

  def freeze_time(time = Time.now)
    @time = time
    Time.stubs(:now).returns(@time)
  end
end
