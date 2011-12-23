class WorldMappedJob
  @queue = :low
  
  def self.perform world_id
    World.find(world_id).tap{|world| world.last_mapped_at = Time.now }.save!
  end
end