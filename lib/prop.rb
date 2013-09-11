require "prop/limiter"
require "forwardable"

module Prop
  VERSION = "0.7.8"

  # Short hand for accessing Prop::Limiter methods
  class << self
    extend Forwardable
    def_delegators :"Prop::Limiter", :read, :write, :configure, :disabled, :before_throttle
    def_delegators :"Prop::Limiter", :throttle!, :throttled?, :count, :query, :reset
  end
end
