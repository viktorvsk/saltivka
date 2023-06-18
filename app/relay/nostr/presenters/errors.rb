module Nostr
  module Presenters
    class Errors
      attr_reader :errors, :format

      DEFAULT_FORMAT = ENV.fetch("DEFAULT_ERRORS_FORMAT", "TEXT")

      def initialize(errors, format = DEFAULT_FORMAT)
        @errors, @format = errors, format
      end

      def to_s
        case format
        when "JSON"
          errors.to_json
        when "TEXT"
          errors.values.join("; ")
        end
      end
    end
  end
end
