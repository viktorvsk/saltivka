class EventDelegator < ApplicationRecord
  belongs_to :event
  belongs_to :author
end
