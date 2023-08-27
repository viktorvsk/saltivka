class UserPubkey < ApplicationRecord
  belongs_to :user
  belongs_to :author
  has_one :author_subscription, through: :author
  validates :author, uniqueness: true
  validates :nip05_name, uniqueness: {case_sensitive: false, allow_blank: true}, length: {maximum: 255, allow_blank: true}

  delegate :pubkey, to: :author, allow_nil: true
end
