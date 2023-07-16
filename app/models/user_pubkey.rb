class UserPubkey < ApplicationRecord
  belongs_to :user
  belongs_to :author
  validates :author, uniqueness: true

  delegate :pubkey, to: :author, allow_nil: true
end
