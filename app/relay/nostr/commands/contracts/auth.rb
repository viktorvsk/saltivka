module Nostr
  module Commands
    module Contracts
      class Auth < Base
        private

        def schema
          Nostr::AUTH_SCHEMA
        end

        def validate_dependent(nostr_event)
        end
      end
    end
  end
end
