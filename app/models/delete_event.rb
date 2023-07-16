class DeleteEvent < ApplicationRecord
  belongs_to :author
  validates :sha256, uniqueness: {scope: [:author]}, length: {is: 64}, presence: true

  scope :by_pubkey_and_sha256, ->(pubkey, sha256) { joins(:author).where(authors: {pubkey: pubkey}, sha256: sha256) }
end
