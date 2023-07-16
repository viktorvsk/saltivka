class Author < ApplicationRecord
  validates :pubkey, presence: true, length: {is: 64}

  has_many :events, dependent: :destroy
  has_many :invoices, dependent: :destroy
  has_one :author_subscription, dependent: :destroy
  has_one :trusted_author, dependent: :destroy, autosave: true
  has_one :user_pubkey, dependent: :destroy
end
