class MinecraftPlayer
  include Mongoid::Document
  include Mongoid::Paranoia
  include Mongoid::Timestamps

  store_in collection: 'minecraft_players'


  attr_accessible :username

# --
# Indexes

  index(
    {deleted_at: 1, slug: 1, _id: 1},
    {unique: true}
  )

  index(
    {_id: 1, user_id: 1}
  )


  REFERRER_CREDITS = 600
  REFEREE_CREDITS = 600

  belongs_to :user
  def verified?
    not user.nil?
  end

  def verify!(user)
    self.user = user
    save!

    # if user.referrer
    #   user.credits += REFEREE_CREDITS
    #   user.save!
    #
    #   user.referrer.credits += REFEREE_CREDITS
    #   user.referrer.save!
    # end

    user.private_channel.trigger!('verified', to_json)

    tell 'Welcome! Your account is now verified'
  end

# ---
# Identity


  def self.sanitize_username(str)
    str.gsub(/[^\w]/, '')[0..16].downcase
  end

  def self.blacklist
    @blacklist ||= File.read(Rails.root.join('config', 'blacklist.txt'))
      .split("\n")
  end

  def self.find_by_username(username)
    find_by(slug: sanitize_username(username))
  end

  field :username, type: String
  validates_exclusion_of :username, in: blacklist
  validates_length_of :username, within: 1..16
  validates_format_of :username, with: /^\w+$/
  validates_uniqueness_of :username, case_sensitive: false

  scope :by_username, ->(username){
    where(slug: sanitize_username(username))
  }

  field :slug, type: String

  def username=(str)
    stripped_username = str.gsub(/[^\w]/, '')[0..16]

    super(stripped_username)
    self.slug = self.class.sanitize_username(stripped_username)
  end

  def to_param
    slug.to_param
  end

  def friendly_id
    user and user.email or username
  end

# ---
# Avatars


  mount_uploader :avatar, AvatarUploader do
    def store_dir
      File.join('player', mounted_as.to_s, model.id.to_s)
    end
  end

  def fetch_avatar
    file = self.class.sanitize_username(username)
    self.remote_avatar_url = "http://minecraft.net/skin/#{file}.png"

  # Minecraft doesn't store default skins so it raises a HTTPError
  rescue OpenURI::HTTPError
  end


# ---
# Worlds


  def worlds
    worlds = World.any_of(
        {opped_player_ids: self.id},
        {whitelisted_player_ids: self.id}
      ).excludes(
        {blacklisted_player_ids: self.id}
      ).order_by([:creator_id, :asc], [:slug, :asc]).to_a

    creator_ids = worlds.map(&:creator_id).uniq

    if creator_ids.empty?
      []
    else
      world_creator_players = MinecraftPlayer.in(user_id: creator_ids)
      user_ids_with_players = world_creator_players.map{|p| p.user_id }

      worlds.select {|w|
        user_ids_with_players.include? w.creator_id
      }.to_a.sort_by{|w| w.name.downcase }
    end
  end

  def online?
    not online_world_id.nil?
  end

  def online_world_id
    $redis.hget('players:playing', id.to_s)
  end

  def online_world
    World.where(_id: online_world_id).first
  end

  def tell(message)
    online_world.tell(self, "[MINEFOLD] #{message}") if online?
  end

# ---
# Stats


  field :minutes_played, type: Integer, default: 0
  field :last_connected_at, type: DateTime

  def played?
    not last_connected_at.nil?
  end
end

