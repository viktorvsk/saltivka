class EventDigest < ApplicationRecord
  include Nostr::Nip13

  has_one :sig, autosave: true, dependent: :destroy
  has_one :event, dependent: :destroy
  validates :sha256, presence: true, length: {is: 64}, uniqueness: true
  delegate :schnorr, to: :sig
  validates_associated :sig
end
