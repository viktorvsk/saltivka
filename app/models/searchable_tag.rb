class SearchableTag < ApplicationRecord
  belongs_to :event
  validates :name, presence: true, length: {maximum: 64}
  validates :value, length: {maximum: 128}
end
