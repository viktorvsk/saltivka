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
          case errors
          when Hash
            errors.values.join("; ")
          when Array
            errors.join("; ")
          else
            errors.to_s
          end
        end
      end
    end
  end
end
