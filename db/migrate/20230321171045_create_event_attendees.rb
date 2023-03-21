class CreateEventAttendees < ActiveRecord::Migration[7.0]
  def change
    create_table :event_attendees do |t|
      t.references :event, null: false, foreign_key: true
      t.string :email
      t.boolean :organizer
      t.string :response_status
      t.boolean :is_self

      t.timestamps
    end
  end
end
