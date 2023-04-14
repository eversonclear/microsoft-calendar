class ExternalEvent < ApplicationRecord
  belongs_to :event
  belongs_to :calendar
end
