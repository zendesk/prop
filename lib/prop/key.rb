require "digest/md5"

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