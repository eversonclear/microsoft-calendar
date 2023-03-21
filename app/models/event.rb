class Event < ApplicationRecord
  include ActiveModel::Serializers::JSON

  belongs_to :user
  belongs_to :calendar

  serialize :reminders, JSON
  serialize :recurrences, JSON
  has_many :event_attendees
end
