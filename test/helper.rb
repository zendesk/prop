# frozen_string_literal: true
require 'bundler/setup'

require "maxitest/global_must"
require "maxitest/autorun"
require 'mocha/minitest'

require 'time'
require 'prop'
require 'active_support/cache'
require 'active_support/cache/memory_store'
require 'active_support/notifications'

begin
  require 'active_support/deprecation'
  require 'active_support/deprecator'
rescue LoadError
end

require 'active_support/core_ext/numeric/time'

Minitest::Test.class_eval do
  def setup_fake_store
    Prop.cache = ActiveSupport::Cache::MemoryStore.new
  end

  def freeze_time(time = Time.now)
    @time = time
    Time.stubs(:now).returns(@time)
  end
end
