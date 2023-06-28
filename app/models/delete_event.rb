class DeleteEvent < ApplicationRecord
  belongs_to :author
  belongs_to :event_digest
  validates :event_digest, uniqueness: {scope: [:author]}

  scope :by_pubkey_and_sha256, ->(pubkey, sha256) { joins(:author, :event_digest).where(authors: {pubkey: pubkey}, event_digests: {sha256: sha256}) }
end
