require "digest/md5"

module Prop
  class Key

    # Builds the expiring cache key
    def self.build(options)
      key       = options.fetch(:key)
      handle    = options.fetch(:handle)
      interval  = options.fetch(:interval)

      window    = (Time.now.to_i / interval)
      cache_key = normalize([ handle, key, window ])

      "prop/#{Digest::MD5.hexdigest(cache_key)}"
    end

    def self.build_bucket_key(options)
      key       = options.fetch(:key)
      handle    = options.fetch(:handle)

      cache_key = normalize([ handle, key ])

      "leaky_bucket/#{Digest::MD5.hexdigest(cache_key)}"
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