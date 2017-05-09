# frozen_string_literal: true
require "prop/limiter"
require "forwardable"

module Prop
  VERSION = "2.2.4"

  # Short hand for accessing Prop::Limiter methods
  class << self
    extend Forwardable
    def_delegators :"Prop::Limiter", :read, :write, :cache=, :configure, :configurations, :disabled, :before_throttle
    def_delegators :"Prop::Limiter", :throttle, :throttle!, :throttled?, :count, :query, :reset
  end
end
