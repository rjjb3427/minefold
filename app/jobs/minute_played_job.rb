class MinutePlayedJob < Job
  @queue = :high

  def initialize(player_id, world_id, timestamp)
    @player = MinecraftPlayer.find(player_id)
    @world = World.unscoped.where(_id: world_id).first
    @timestamp = timestamp
  end

  def perform!
    @player.inc :minutes_played, 1
    @world.inc :minutes_played, 1
  end

end
