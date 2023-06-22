class Event < ApplicationRecord
  include Nostr::Nip1
  include Nostr::Nip9
end
