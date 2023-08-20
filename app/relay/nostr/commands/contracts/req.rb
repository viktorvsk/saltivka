module Nostr
  module Commands
    module Contracts
      class Req < Base
        private

        def schema
          Nostr::REQ_SCHEMA
        end

        def validate_dependent(nostr_event)
          # we are confident its exactly filters here because we run this validation only if schema is correct
          filters = nostr_event[2..]

          filters.each_with_index do |filter_set, index|
            if filter_set["since"].present? && filter_set["until"].present?
              add_error("filters/#{index}/since-gt-until", "when both specified, until has always to be after since")
            end
          end
        end
      end
    end
  end
end
