class PlayerOppedJob < TweetJob
  @queue = :low

  def self.perform world_id, username
    user = User.by_username(User.sanitize_username(username)).first
    membership = World.find(world_id).memberships.where(user_id: user.id).first
    membership.role = 'op'
    membership.save
  end
end