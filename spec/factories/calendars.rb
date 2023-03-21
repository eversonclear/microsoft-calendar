FactoryBot.define do
  factory :calendar do
    user { nil }
    access_role { "MyString" }
    background_color { "MyString" }
    color_id { "MyString" }
    description { "MyString" }
    default_reminders { "MyText" }
    conference_properties { "MyText" }
    etag { "MyString" }
    foreground_color { "MyString" }
    remote_id { "MyString" }
    kind { "MyString" }
    selected { false }
    summary { "MyString" }
    summary_override { "MyString" }
    primary { false }
    deleted { false }
    hidden { false }
    time_zone { "MyString" }
  end
end
