require "prop/limiter"
require "forwardable"

module Prop
  VERSION = "1.0.2"

  # Short hand for accessing Prop::Limiter methods
  class << self
    extend Forwardable
    def_delegators :"Prop::Limiter", :read, :write, :configure, :handles, :disabled, :before_throttle
    def_delegators :"Prop::Limiter", :throttle, :throttle!, :throttled?, :count, :query, :reset
  end
end
