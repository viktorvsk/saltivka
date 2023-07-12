class Invoice < ApplicationRecord
  PROVIDERS = {
    opennode: (RELAY_CONFIG.provider_api_key_open_node.presence && OpenNode.new(RELAY_CONFIG.provider_api_key_open_node))
  }.reject { |pname, provider| provider.nil? }
  STATUSES = %w[pending created partially_paid expired paid failed]

  belongs_to :author
  validates :amount_sats, :provider, :period_days, :order_id, presence: true
  validates :amount_sats, :period_days, numericality: {only_integer: true, greater_than: 0}

  validates :provider, inclusion: {in: PROVIDERS.keys.map(&:to_s)}
  validates :status, inclusion: {in: STATUSES}
  validates :order_id, uniqueness: true

  delegate :pubkey, to: :author, allow_nil: true

  def pubkey=(value)
    self.author = Author.create_or_find_by(pubkey: value)
  end
end
