class SearchableTag < ApplicationRecord
  belongs_to :event
  validates :name, presence: true
  validates :value, presence: true
end
