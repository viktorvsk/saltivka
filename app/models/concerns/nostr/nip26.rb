module Nostr
  module Nip26
    extend ActiveSupport::Concern

    included do
      validate :validate_delegation_nip26

      private

      def validate_delegation_nip26
        # TODO:
      end
    end
  end
end
