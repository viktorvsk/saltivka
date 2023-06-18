module Nostr
  module Commands
    module Contracts
      class Base
        def initialize
          @errors = []
        end

        def call(nostr_event)
          schema.validate(nostr_event).each { |error| add_error(error["data_pointer"], JSONSchemer::Errors.pretty(error)) }

          validate_dependent(nostr_event) if @errors.blank?

          OpenStruct.new(success?: @errors.blank?, failure?: @errors.present?, errors: grouped_errors)
        end

        private

        def add_error(key, value)
          @errors.push(key: key, value: value)
        end

        def grouped_errors
          @errors.group_by { |e| e[:key] }.transform_values { |errors| errors.map { |e| e[:value] } }
        end

        def schema
          raise NotImplementedError, "This method is not yet implemented."
        end

        def validate_dependent(nostr_event)
          raise NotImplementedError, "This method is not yet implemented."
        end
      end
    end
  end
end
