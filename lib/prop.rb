# frozen_string_literal: true
require "prop/limiter"
require "forwardable"

module Prop
  VERSION = "2.9.0"

  # Short hand for accessing Prop::Limiter methods
  class << self
    extend Forwardable
    def_delegators :"Prop::Limiter", :read, :write, :cache, :cache=, :configure, :configurations, :disabled, :before_throttle
    def_delegators :"Prop::Limiter", :throttle, :throttle!, :throttled?, :count, :query, :reset, :after_evaluated
  end
end
