module Nostr
  module Presenters
    class Errors
      attr_reader :errors, :format

      def initialize(errors, format = RELAY_CONFIG.default_format)
        @errors, @format = errors, format
      end

      def to_s
        case format
        when "JSON"
          errors.to_json
        when "TEXT"
          # TODO: handle different types, now only hash is supported
          errors.values.join("; ")
        end
      end
    end
  end
end
