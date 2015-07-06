require "digest/md5"
require "prop/interval_strategy"
require "prop/leaky_bucket_strategy"

module Prop
  class Key

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