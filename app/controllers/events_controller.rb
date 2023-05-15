class EventsController < ApplicationController
  before_action :treat_recurrence, only: %i[ create update ]
  before_action :set_event, only: %i[ show update destroy ]
  before_action :set_google_calendar_service

  # GET /events
  # GET /events.json
  def index
    @events = Event.all
  end

  # GET /events/1
  # GET /events/1.json
  def google_calendar_events 
    events = @google_calendar_service.list_events(params[:calendar_id])
   
    render json: events.items.to_json
  end

  def events_by_date
    calendar_ids = Calendar.where(user_id: current_user).uniq
    selected_date = Date.parse(params[:date])

    set_recurring_events(selected_date)

    @events = Event.where(:starts_at => selected_date.beginning_of_day..selected_date.end_of_day).where(calendar_id: calendar_ids).order(starts_at: :asc)
    
    all_day_events = selected_events.select{ |f| f.is_all_day == true }.uniq
    today_events = selected_events.select{ |f| f.is_all_day == false }.uniq

    render json: {today_events: today_events, all_day_events: all_day_events}, status: :ok
  end

  def selected_events
    @events + @recurring_events
  end

  def events_by_week
    calendar_ids = Calendar.where(user_id: current_user)
    start_date = Date.parse(params[:start])
    end_date = Date.parse(params[:end])

    recurrent_events = weekly_recurring_events(calendar_ids) 

    non_recurrent_events = Event.where('starts_at >= ? AND starts_at <= ?', start_date, end_date).where(calendar_id: calendar_ids)

    week_events = recurrent_events.length === 7 ? recurrent_events : recurrent_events + non_recurrent_events

    @events = week_events.uniq{|x| Date.parse(x.starts_at.to_s)}

    render json: @events, status: :ok
  end

  def events_by_range 
    calendar_ids = Calendar.where(user_id: current_user).uniq
    selected_start_date = Date.parse(params[:start])
    selected_end_date = Date.parse(params[:end]) + 1
    recurrent_events = recurring_events_in_range(calendar_ids)

    @events = Event.where(:starts_at => selected_start_date.beginning_of_day..selected_end_date.end_of_day).where(calendar_id: calendar_ids).order(starts_at: :asc)

    @events = @events + recurrent_events

    render json: @events, status: :ok
  end
  def show
  end

  # POST /events
  # POST /events.json
  def create
    calendar = Calendar.where(user_id: current_user).first
    @event = Event.new(event_params.merge!(recurrence: @recurrence_ical_format, user_id: current_user.id, calendar_id: calendar.id))

    if @event.save
      render :show, status: :created, location: @event
    else
      render json: @event.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /events/1
  # PATCH/PUT /events/1.json
  def update
    if @event.update(event_params.merge!(recurrence: @recurrence_ical_format || params[:event][:recurrence]))
      render :show, status: :ok, location: @event
    else
      render json: @event.errors, status: :unprocessable_entity
    end
  end

  # DELETE /events/1
  # DELETE /events/1.json
  def destroy
    @event.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.

    def treat_recurrence
      return if event_params[:recurrence].blank?
      @recurrence_ical_format = TreatRecurrenceService.to_ical_format(event_params[:recurrence].as_json.deep_symbolize_keys)
    end

    def set_recurring_events(selected_date)
      all_recurrent_events = Event.where('recurrence is NOT NULL AND user_id = ?', current_user.id)

      recurring_events = []

      all_recurrent_events.each do |event|
        schedule = IceCube::Schedule.from_ical(event.recurrence[0])
        if has_recurring_events?(schedule, selected_date)
          recurring_events.push(event)
        end
      end

      @recurring_events = recurring_events
    end

    def weekly_recurring_events(calendar_ids) 
      all_recurrent_events = Event.where("recurrence is NOT NULL").where(calendar_id: calendar_ids)

      recurrent_events = []

      (Date.parse(params[:start])..Date.parse(params[:end])).map.each do |day| 
        all_recurrent_events.each do |event|
          schedule = IceCube::Schedule.from_ical(event.recurrence[0])

          if schedule.occurs_on?(day)
            starts_at_hours = event.starts_at.strftime('%I:%M%p')
            finishes_at_hours = event.finishes_at.strftime('%I:%M%p')
            event.starts_at = "#{day} #{starts_at_hours} UTC".to_datetime
            event.finishes_at = "#{day} #{finishes_at_hours} UTC".to_datetime
            newEvent = Event.new({summary: event.summary,  starts_at: event.starts_at, finishes_at: event.finishes_at})

            recurrent_events.push(newEvent)
            break
          end
        end
      end
      
      recurrent_events
    end

    def has_recurring_events?(event, date)
      event.occurs_on?(date)
    end

    def recurring_events_in_range(calendar_ids)
      all_recurrent_events = Event.where('recurrence is NOT NULL').where(calendar_id: calendar_ids)

      recurrent_events = []

      (Date.parse(params[:start])..Date.parse(params[:end]) + 1).map.each do |day|
        all_recurrent_events.each do |event|
          schedule = IceCube::Schedule.from_ical(event.recurrence[0])

          if schedule.occurs_on?(day)
            starts_at_hours = event.starts_at.strftime('%I:%M%p')
            finishes_at_hours = event.finishes_at.strftime('%I:%M%p')
            event.starts_at = "#{day} #{starts_at_hours} UTC".to_datetime
            event.finishes_at = "#{day} #{event.is_all_day ? day.end_of_day : finishes_at_hours} UTC".to_datetime
            newEvent = Event.new({id: event.id, recurrence: event.recurrence[0], summary: event.summary, starts_at: event.starts_at, finishes_at: event.finishes_at, is_all_day: event.is_all_day})
            recurrent_events.push(newEvent)
          end
        end
      end

      recurrent_events
   end

    def set_google_calendar_service
      token = AccessTokenService.new current_user.google_token

      @google_calendar_service = Google::Apis::CalendarV3::CalendarService.new
      @google_calendar_service.authorization = token
    end

    def set_event
      @event = Event.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def event_params
      params.require(:event).permit(:user_id, :calendar_id, :remote_created_at, :remote_updated_at, :starts_at, :starts_at_timezone, :finishes_at, :finishes_at_timezone, :self_sequence, :location, :description, :creator_email, :creator_id, :creator_display_name, :self_created, :etag, :event_type, :web_link, :i_cal_uid, :remote_id, :kind, :organizer_email, :organizer_id, :organizer_display_name, :self_organized, :reminders, :status, :summary, :transparency, :allow_new_time_proposals, :body_content_type, :body_content, :categories, :change_key, :has_attachments, :importance, :is_all_day, :is_cancelled, :is_draft, :is_online_meeting, :is_organizer, :end_time_unspecified, :is_reminder_on, :locations, :online_meeting, :online_meeting_provider, :online_meeting_url, :original_starts_at, :original_timezone_starts_at, :reminder_minutes_before_start, :series_master_id, :response_status_text, :response_status_time, :response_requested, :show_as, :transaction_id, :visibility, :attendees_omitted, :extended_properties, :hangout_link, :conference_data, :gadget, :anyone_can_add_self, :guests_can_invite_others, :guests_can_modify, :guests_can_see_other_guests, :private_copy, :locked, :source_url, :source_title, :color_id, :working_location_properties, :attachments, :original_finishes_at_timezone, event_attendees_attributes: [:id, :email, :display_name, :comment, :resource, :optional, :response_status, :is_self, :organizer], :recurrence => {})
    end
end
