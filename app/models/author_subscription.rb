class AuthorSubscription < ApplicationRecord
  belongs_to :author

  scope :active, -> { where("expires_at > ?", Time.current) }
end
