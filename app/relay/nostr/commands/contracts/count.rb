module Nostr
  module Commands
    module Contracts
      class Count < Base
        private

        def schema
          Nostr::COUNT_SCHEMA
        end

        def validate_dependent(nostr_event)
        end
      end
    end
  end
end
