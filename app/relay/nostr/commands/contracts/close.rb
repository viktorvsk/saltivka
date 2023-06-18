module Nostr
  module Commands
    module Contracts
      class Close < Base
        private

        def schema
          Nostr::CLOSE_SCHEMA
        end

        def validate_dependent(nostr_event)
        end
      end
    end
  end
end
