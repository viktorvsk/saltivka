module Nostr
  module Nip22
    extend ActiveSupport::Concern

    included do
      validates :created_at, inclusion: {in: ->(event) { RELAY_CONFIG.created_at_in_past.seconds.ago..RELAY_CONFIG.created_at_in_future.seconds.from_now }, message: "must be within limits"}
    end
  end
end
