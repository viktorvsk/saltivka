class Author < ApplicationRecord
  validates :pubkey, presence: true, length: {is: 64}

  has_many :events, dependent: :destroy
  has_one :trusted_author, dependent: :destroy
end
