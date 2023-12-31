class Author < ApplicationRecord
  validates :pubkey, presence: true, length: {is: 64}
  validate :lower_pubkey_uniqueness, on: :create

  has_many :events, dependent: :destroy
  has_many :invoices, dependent: :destroy
  has_one :author_subscription, dependent: :destroy
  has_one :trusted_author, dependent: :destroy, autosave: true
  has_one :user_pubkey, dependent: :destroy

  def self.from_pubkey(pk)
    select(:id, :pubkey).where("LOWER(authors.pubkey) = ?", pk.downcase).first_or_create(pubkey: pk.downcase)
  rescue ActiveRecord::RecordNotUnique
    select(:id, :pubkey).where("LOWER(authors.pubkey) = ?", pk.downcase).first
  end

  private

  def lower_pubkey_uniqueness
    if Author.where("LOWER(authors.pubkey) = ?", pubkey).exists?
      errors.add(:pubkey, "has already been taken")
    end
  end
end
