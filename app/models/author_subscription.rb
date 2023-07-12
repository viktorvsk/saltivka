class AuthorSubscription < ApplicationRecord
  belongs_to :author

  validates :author, uniqueness: true

  scope :active, -> { where("expires_at > ?", Time.current) }
end
