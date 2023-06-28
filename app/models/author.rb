class Author < ApplicationRecord
  validates :pubkey, presence: true, length: {is: 64}, uniqueness: true # TODO: add db index

  has_many :events, dependent: :destroy
end
