class DeleteEvent < ApplicationRecord
  validates :event_id, uniqueness: {scope: [:pubkey]}
  validates :pubkey, :event_id, length: {is: 64}, presence: true
end
