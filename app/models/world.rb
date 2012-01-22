class World
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Slug

  scope :by_name, ->(name) {
    where(name: name)
  }

  field :name, type: String
  slug :name, index: true, scope: :creator
  validates_presence_of :name

  scope :by_name, ->(name) {
    where(name: name)
  }


  belongs_to :creator,
    inverse_of: :created_worlds,
    class_name: 'User'
  validates_presence_of :creator

  scope :by_creator, ->(creator) {
    where(creator_id: creator.id)
  }

  def self.find_by_creator_and_slug!(creator, slug)
    by_creator(creator).find_by_slug!(slug)
  end


  # Cloning

  belongs_to :parent, inverse_of: :children, class_name: 'World'
  has_many :children, inverse_of: :parent, class_name: 'World'


  # Data

  # this is the world backup file in S3, can be blank
  field :filename, type: String, default: -> {"#{id}.tar.gz"}
  belongs_to :world_upload

  after_create do
    # if world is being created from an upload, use the uploaded world data file as our starting point
    if world_upload
      self.filename = world_upload.world_data_file
      save!
    end
  end

  field :last_mapped_at, type: DateTime


  # Peeps

  embeds_many :memberships

  embeds_many :membership_requests do
    def include_user?(user)
      where(user_id: user.id).exists?
    end
  end

  has_many :events, as: :target,
                    order: [:created_at, :desc]


  # Game settings

  LEVEL_TYPES = ['default', 'flat']
  GAME_MODES = [:survival, :creative]
  DIFFICULTIES = [:peaceful, :easy, :normal, :hard]

  field :level_type,       type: String,  default: LEVEL_TYPES.first
  field :pvp,              type: Boolean, default: true
  field :spawn_monsters,   type: Boolean, default: true
  field :spawn_animals,    type: Boolean, default: true

  field :seed, type: String, default: ''

  field :game_mode, type: Integer, default: GAME_MODES.index(:survival)
  validates_numericality_of :game_mode,
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than: GAME_MODES.size

  field :difficulty_level, type: Integer, default: DIFFICULTIES.index(:easy)
  validates_numericality_of :difficulty_level,
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than: DIFFICULTIES.size


  # Stats

  field :minutes_played, type: Integer, default: 0

  def minute_played!
    inc :minutes_played, 1
  end

  field :pageviews, type: Integer, default: 0
  validates_numericality_of :pageviews,
    only_integer: true,
    greater_than_or_equal_to: 0


  # Users

  def creator=(creator)
    write_attribute :creator_id, creator.id
    add_op(creator)
  end

  def add_member(user)
    memberships.find_or_initialize_by user: user
  end

  def add_op(user)
    add_member(user).tap {|m| m.op! }
  end

  def member?(user)
    memberships.where(user_id: user.id).exists?
  end

  def op?(user)
    memberships.ops.where(user_id: user.id).exists?
  end

  def ops
    memberships.ops.map {|m| m.user }
  end

  def members
    memberships.map {|m| m.user }
  end

  def players
    User.find(current_player_ids)
  end

  def offline_players
    User.find(memberships.map {|m| m.user_id} - current_player_ids)
  end


  # Communication

  def record_event!(type, attrs)
    event = type.new(attrs)
    self.events.push(event) if event.valid?
    event
  end

  def broadcast(event_name, data, socket_id=nil)
    pusher_channel.trigger event_name, data, socket_id
  end

  def say(msg)
    send_stdin "say #{msg}"
  end

  def tell(user, msg)
    send_stdin "/tell #{user.username} #{msg}"
  end


  # Maps

  def mapped?
    not last_mapped_at.nil?
  end

  def map_assets_url
    case
    when mapped?
      File.join(ENV['WORLD_MAPS_URL'], id.to_s)
    when clone?
      parent.map_assets_url
    end
  end


  # Uploads

  def upload_filename_prefix
    [creator.safe_username, creator.id, Time.now.strftime('%Y%m%d%H%M%S'), nil].join('-')
  end


  # Cloning

  def clone?
    !parent.nil?
  end

  def clone!
    self.class.new({
      parent: self,
      name: name,
      filename: filename,
      seed: seed,
      game_mode: game_mode,
      difficulty_level: difficulty_level
    })
  end


# Other

  def to_param
    slug.to_param
  end

  def pusher_key
    "#{collection.name.downcase}-#{id}"
  end

  def redis_key
    "#{collection.name.downcase}:#{id}"
  end

  def current_player_ids
    REDIS.smembers("#{redis_key}:connected_players").map {|id| BSON::ObjectId(id)}
  end

private

  def pusher_channel
    Pusher[pusher_key]
  end

  def send_stdin(str)
    world_data = REDIS.hget "worlds:running", id
    if world_data
      instance_id = JSON.parse(world_data)['instance_id']
      REDIS.publish("workers:#{instance_id}:worlds:#{id}:stdin", str)
    end
  end

end
