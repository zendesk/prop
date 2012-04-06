require 'prop/key'

module Prop
  class Options

    # Sanitizes the option set and sets defaults
    def self.build(options)
      key      = options.fetch(:key)
      params   = options.fetch(:params)
      defaults = options.fetch(:defaults)
      result   = defaults.merge(params)

      result[:key]       = Prop::Key.normalize(key)
      result[:threshold] = result[:threshold].to_i
      result[:interval]  = result[:interval].to_i

      raise RuntimeError.new("Invalid threshold setting") unless result[:threshold] > 0
      raise RuntimeError.new("Invalid interval setting")  unless result[:interval] > 0

      result
    end

  end
end