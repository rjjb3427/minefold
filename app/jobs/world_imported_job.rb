class WorldImportedJob < Job
  @queue = :low

  def initialize(result, server_pc_id, snapshot_id, url, settings, pusher_key)
    @result = result
    @server = Server.find_by_party_cloud_id(server_pc_id)
    @snapshot_id = snapshot_id
    @url = url
    @settings = settings
    @pusher_key = pusher_key
  end

  def perform!
    if @result == 'success'
      @server.settings.merge!(@settings)
      @server.save!

      @server.snapshots.create(
        party_cloud_id: @snapshot_id,
        url: @url
      )

      pusher.trigger('success', {})

    else
      pusher.trigger('error', @result)
      raise @result.inspect
    end
  end

private

  def pusher
    @pusher ||= Pusher[@pusher_key]
  end

end
