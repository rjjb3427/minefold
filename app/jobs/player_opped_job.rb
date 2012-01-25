class PlayerOppedJob
  @queue = :low

  def self.perform(world_id, player_username)
    world = World.find(world_id)
    user = User.by_username(player_username).first

    return unless user

    new.process! world, user
  end

  def process!(world, user)
    membership = world.memberships.where(user_id: user.id).first
    membership.op!

    world.save
  end
end
