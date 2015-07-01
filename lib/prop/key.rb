require "digest/md5"
require "prop/base_strategy"
require "prop/leaky_bucket_strategy"

module Prop
  class Key

    # Builds the expiring cache key by strategy class
    def self.build(strategy, options)
      strategy.build(options)
    end

    # Simple key expansion only supports arrays and primitives
    def self.normalize(key)
      if key.is_a?(Array)
        key.flatten.join("/")
      else
        key.to_s
      end
    end

  end
end