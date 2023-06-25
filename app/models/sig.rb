class Sig < ApplicationRecord
  belongs_to :event_digest
  validates :schnorr, presence: true, length: {is: 128}, uniqueness: true
end
