class TrustedAuthor < ApplicationRecord
  belongs_to :author
  validates :author, uniqueness: true
end
