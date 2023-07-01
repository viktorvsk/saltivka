class SearchableTag < ApplicationRecord
  belongs_to :event
  validates :name, presence: true, length: {maximum: 64}
  validates :value, presence: true
end
