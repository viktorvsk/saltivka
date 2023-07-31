class RelayMirror < ApplicationRecord
  validates :url, uniqueness: true
  validates :active, inclusion: {in: [true, false]}
end
