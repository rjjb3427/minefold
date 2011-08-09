class User
  include MongoMapper::Document
  include Gravtastic

  BILLING_PERIOD = 1.minute
  DEFAULT_INVITES  = 10
  FREE_HOURS  = 1.hour

  key :email,    String,  unique: true
  key :username, String
  key :credits,  Integer, default: (FREE_HOURS / BILLING_PERIOD)
  key :minutes_played,  Integer, default: 0

  one :invite

  many :wall_items, as: :wall
  belongs_to :world
  timestamps!

  validates_uniqueness_of :username, allow_nil: true

  devise :registerable,
         :database_authenticatable,
         :recoverable,
         :rememberable,
         :trackable,
         :validatable

  gravtastic secure: true,
             format: :png,
             default: 'identicon'

  attr_accessible :email,
                  :username,
                  :password,
                  :password_confirmation,
                  :invite_code

  def first_signin?
    sign_in_count <= 1
  end

  before_create do
    self.word = World.default
  end


# Credits

  def increment_credits n
    increment credits: (n / BILLING_PERIOD)
    reload
    n
  end

  def hours
    (credits * BILLING_PERIOD) / 1.hour
  end

  def minutes
    credits - (hours * (1.hour / BILLING_PERIOD))
  end

# Invites

  def free_invites?
    invites > 0
  end

  def invite_code=(code)
    self.invite = Invite.unclaimed.find_by_code(code.downcase)
  end

  after_create do
    self.invite.user = self
    self.invite.save
  end

  validates_presence_of :invite, on: :create

protected

  def self.chris
    find_by_email 'chris@minefold.com'
  end

  def self.dave
    find_by_email 'dave@minefold.com'
  end

end
