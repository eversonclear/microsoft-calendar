class Calendar < ApplicationRecord
  include ActiveModel::Serializers::JSON
  
  belongs_to :user

  serialize :conference_properties, JSON
  serialize :default_reminders, JSON
  
  has_many :events
end
