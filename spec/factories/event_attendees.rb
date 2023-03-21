FactoryBot.define do
  factory :event_attendee do
    event { nil }
    email { "MyString" }
    organizer { false }
    response_status { "MyString" }
    is_self { false }
  end
end
