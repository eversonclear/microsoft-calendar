require 'microsoft_graph'
require 'net/http'

class PullUserMicrosoftCalendarsWorker
  include Sidekiq::Job

  def perform(current_user_id, web=true)
    @current_user = User.find(current_user_id)
    @origin = web ? ENV['ORIGIN_HEADER_MICROSOFT_GRAPH'] : ''
 
    refresh_token_if_invalid
    set_microsoft_azure_calendar_service
    update_user_calendars
  end

  def refresh_token_if_invalid
    @microsoft_service = MicrosoftService.new

    if !@microsoft_service.access_token_is_valid?(@current_user.azure_expire_token)
      data_token = @microsoft_service.refresh_token(@current_user.azure_refresh_token, @origin)
      @current_user.update(azure_token: data_token["access_token"], azure_expire_token: Time.now + data_token['expires_in'])
    end
  end

  def set_microsoft_azure_calendar_service
    callback =  Proc.new do |r|
      r.headers['Authorization'] = "Bearer #{@current_user.azure_token}"
      r.headers['Content-Type']  = 'application/json'
      r.headers['X-AnchorMailbox'] = @current_user.email
    end
    
    @graph_service = MicrosoftGraph.new(base_url: 'https://graph.microsoft.com/v1.0', cached_metadata_file: File.join(MicrosoftGraph::CACHED_METADATA_DIRECTORY, "metadata_v1.0.xml"), &callback).service
  end

  def update_user_calendars
    calendars = @graph_service.get('me/calendars')
    
    calendars[:attributes]["value"].map do |calendar_item|
      @calendar = Calendar.where(remote_id: calendar_item["id"]).first     
      
      if @calendar.present?
        @calendar.update(calendar_params(calendar_item))
      else
        @calendar = Calendar.create!(calendar_params(calendar_item))
      end

      events = @graph_service.get("me/calendars/" + calendar_item["id"] + "/events")

      events[:attributes]["value"].map do |event_item|
        @event = Event.where(calendar_id: @calendar["id"], remote_id: event_item["id"]).first             
        if @event.present?
          @event.update_columns(**event_params(event_item))
        else
          row_id = @calendar.events.insert!(event_params(event_item))
          @event = Event.find(row_id.first["id"])
          @event.external_events.create(calendar_id: @calendar.id, external_id: @event.remote_id)
        end

        if event_item["attendees"].present?
          event_item["attendees"].each do |event_attendee|
            @event_attendee = EventAttendee.where(event_id: @event.id, email: event_attendee["emailAddress"]["address"]).first  

            if @event_attendee.present?
              @event_attendee.update(event_attendee_params(event_attendee))
            else
              @event.event_attendees.create!(event_attendee_params(event_attendee))
            end
          end
        end    
      end
    end
  end

  def calendar_params(calendar)
    {
      user_id: @current_user.id,
      background_color: calendar["hexColor"],
      color_id: calendar["color"],
      remote_id: calendar["id"],
      summary: calendar["name"],
      primary: calendar["isDefaultCalendar"],
      change_key: calendar["changeKey"],
      can_share: calendar["canShare"],
      can_edit: calendar["canEdit"],
      allowed_online_meeting_providers: calendar["allowedOnlineMeetingProviders"],
      default_online_meeting_provider: calendar["defaultOnlineMeetingProvider"],
      is_tallying_responses: calendar["isTallyingResponses"],
      is_removable: calendar["isRemovable"],
      owner_name: calendar["owner"]["name"],
      owner_email: calendar["owner"]["address"]
    }
  end

  def event_params(event)
    {
      calendar_id: @calendar.id,
      user_id: @current_user.id,
      location: event["location"]["displayName"] || '',
      description: event["bodyPreview"] || '',
      remote_created_at: event["createdDateTime"],
      remote_updated_at: event["lastModifiedDateTime"],
      starts_at: event["start"]["dateTime"],
      starts_at_timezone: event["start"]["timeZone"],
      finishes_at: event["end"]["dateTime"],
      finishes_at_timezone: event["end"]["timeZone"] || '',
      etag: event["@odata.etag"],
      i_cal_uid: event["iCalUId"],
      remote_id: event["id"],
      categories: event["categories"],
      organizer_email: event["organizer"]["emailAddress"]["address"],
      self_organized: event["isOrganizer"],
      summary: event["subject"],
      recurrence: event["recurrence"],
      allow_new_time_proposals: event["allowNewTimeProposals"],
      body_content: event["body"]["content"],
      body_content_type: event["body"]["contentType"],
      has_attachments: event["hasAttachments"],
      attendees_omitted: event["hideAttendees"],
      importance: event["importance"],
      is_all_day: event["isAllDay"],
      is_cancelled: event["isCancelled"],
      is_draft: event["isDraft"],
      is_online_meeting: event["isOnlineMeeting"],
      is_organizer: event["isOrganizer"],
      is_reminder_on: event["isReminderOn"],
      locations: event["locations"],
      online_meeting: event["onlineMeeting"],
      online_meeting_provider: event["onlineMeetingProvider"],
      online_meeting_url: event["onlineMeetingUrl"],
      original_finishes_at_timezone: event["originalEndTimeZone"],
      original_timezone_starts_at: event["originalStartTimeZone"],
      original_starts_at: event["originalStart"],
      reminder_minutes_before_start: event["reminderMinutesBeforeStart"],
      response_requested: event["responseRequested"],
      response_status_text: event["responseStatus"]["response"],
      response_status_time: event["responseStatus"]["time"],
      visibility: event["sensitivity"],
      series_master_id: event["seriesMasterId"],
      show_as: event["showAs"],
      transaction_id: event["transactionId"],
      event_type: event["type"],
      web_link: event["webLink"],
      change_key: event["changeKey"]
    }
  end

  def event_attendee_params(event_attendee)
    {
      event_id: @event.id,
      email: event_attendee["emailAddress"]["address"],
      display_name: event_attendee["emailAddress"]["name"],
      response_status: event_attendee["status"]["response"],
      response_status_time: event_attendee["status"]["time"],
      type: event_attendee["time"],
    }
  end
end
