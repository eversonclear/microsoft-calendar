class SyncGoogleUserEventsWorker
  include Sidekiq::Job

  def perform(event_id, action)
    calendar_remote_ids = Calendar.where(access_role: ['writer', 'owner'], should_sync: true).ids
    @calendars = Calendar.where(id: calendar_remote_ids)
    return if @calendars.empty?

    @action = action
    @event = Event.find(event_id)
    @current_user = User.find(@calendars[0].as_json['user_id'])

    refresh_token_if_invalid
    set_microsoft_azure_calendar_service
    perform_action
  end

  def perform_action
    case @action
    when 'create'
      
    when 'update'
      
    when 'delete'
      
    else
      puts 'Unknown action'
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

  def refresh_token_if_invalid
    @microsoft_service = MicrosoftService.new

    if !@microsoft_service.access_token_is_valid?(@current_user.azure_expire_token)
      data_token = @microsoft_service.refresh_token(@current_user.azure_refresh_token, @origin)
      @current_user.update(azure_token: data_token["access_token"], azure_expire_token: Time.now + data_token['expires_in'])
    end
  end
end