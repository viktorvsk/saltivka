class EventDigest < ApplicationRecord
  include Nostr::Nip13

  has_one :sig, autosave: true
  has_one :event
  validates :sha256, presence: true, length: {is: 64}, uniqueness: true
  delegate :schnorr, to: :sig
  validates_associated :sig
end
