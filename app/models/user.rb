class User < ApplicationRecord
  EMAIL_CONFIRM_EXPIRATION_SECONDS = 8.hours.to_i

  authenticates_with_sorcery!

  validates :password, length: {minimum: 3}, if: -> { new_record? || changes[:crypted_password] }
  validates :password, confirmation: true, if: -> { new_record? || changes[:crypted_password] }
  validates :password_confirmation, presence: true, if: -> { new_record? || changes[:crypted_password] }

  validates :email, uniqueness: true, presence: true

  scope :active, -> { where.not(confirmed_at: nil) }
  scope :paid, -> { joins(:author_subscriptions).where("author_subscriptions.expires_at > ?", Time.current) }

  has_many :user_pubkeys, dependent: :destroy
  has_many :authors, through: :user_pubkeys
  has_many :author_subscriptions, through: :authors
  has_many :nip05_names, dependent: :delete_all

  def active?
    confirmed_at.present?
  end
end
