FactoryBot.define do
  factory :event do
    user { nil }
    calendar { nil }
    remote_created_at { "2023-03-21 14:10:32" }
    remote_updated_at { "2023-03-21 14:10:32" }
    starts_at { "2023-03-21 14:10:32" }
    starts_at_timezone { "MyString" }
    finishes_at { "2023-03-21 14:10:32" }
    finishes_at_timezone { "MyString" }
    self_sequence { 1 }
    location { "MyString" }
    description { "MyString" }
    creator_email { "MyString" }
    self_created { false }
    etag { "MyString" }
    event_type { "MyString" }
    html_link { "MyString" }
    i_cal_uid { "MyString" }
    remote_id { "MyString" }
    kind { "MyString" }
    organizer_email { "MyString" }
    self_organized { false }
    reminders { "MyText" }
    status { "MyString" }
    summary { "MyString" }
    transparency { "MyString" }
    recurrences { "MyString" }
  end
end
