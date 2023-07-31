class RelayMirror < ApplicationRecord
  validates :url
  validates :active, inclusion: {in: [true, false]}
  validates :mirror_type, inclusion: {in: %w[past future]}
  validates :oldest, :newest, numericality: {only_integer: true}
  validates :newest, comparison: {greater_than: :oldest}
end
