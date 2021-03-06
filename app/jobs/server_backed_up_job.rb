class ServerBackedUpJob < Job
  @queue = :high

  def initialize(pc_server_id, snapshot_id, url)
    @server = Server.unscoped.find_by_party_cloud_id(pc_server_id)
    @snapshot_id, @url = snapshot_id, url
  end

  def perform
    if not @server.world
      @server.world = World.new
    end

    @server.world.party_cloud_id = @snapshot_id
    @server.world.legacy_url = @url
    @server.world.save!

    # Map persistant servers once a day
    if @server.creator.has_maps? and @server.world.needs_map?
      @server.world.map_queued_at = Time.now
      @server.world.save!

      Atlas.map_server @server.id, @url
    end

    PartyCloud::Server.new(@server.party_cloud_id).compact_snapshots!
  end

end
