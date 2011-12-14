class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Slug
  include Mongoid::Paranoia

  BILLING_PERIOD = 1.minute
  FREE_HOURS  = 10

  REFERRAL_CODE_LENGTH = 6
  REFERRAL_HOURS = 2

  field :email,          type: String
  field :username,       type: String
  field :safe_username,  type: String
  slug  :username,       index: true

  field :host,           default: 'pluto.minefold.com'

  field :unlimited,      type: Boolean, default: false

  field :credits,        type: Integer, default: (FREE_HOURS.hours / BILLING_PERIOD)
  field :minutes_played, type: Integer, default: 0

  attr_accessor :stripe_token
  field :stripe_id,               type: String
  embeds_one :card

  field :referral_code,   type: String, default: -> {
    begin
      c = rand(36 ** REFERRAL_CODE_LENGTH).to_s(36).rjust(REFERRAL_CODE_LENGTH, '0').upcase
    end while self.class.where(code: c).exists?
    c
  }
  validates_uniqueness_of :referral_code
  
  belongs_to :referrer,  class_name: 'User', inverse_of: :referrals
  has_many   :referrals, class_name: 'User', inverse_of: :referrer


  belongs_to :current_world, class_name: 'World', inverse_of: nil
  has_many :created_worlds, class_name: 'World', inverse_of: :creator

  has_and_belongs_to_many :whitelisted_worlds,
                          inverse_of: :whitelisted_players,
                          class_name: 'World'

  has_and_belongs_to_many :opped_worlds,
                          inverse_of: :ops,
                          class_name: 'World'

  attr_accessor :email_or_username
  

# Finders

  index :email, unique: true
  scope :by_email, ->(email) {
    where(email: sanitize_email(email))
  }

  index :safe_username, unique: true
  scope :by_username, ->(username) {
    where(safe_username: sanitize_username(username))
  }
  scope :by_email_or_username, ->(str) {
    any_of(
      {safe_username: sanitize_username(str)},
      {email: sanitize_email(str)}
    )
  }

  index :stripe_id, unique: true
  scope :by_stripe_id, ->(stripe_id) {
    where(stripe_id: stripe_id)
  }


# Validations

  validates_presence_of :username
  validates_uniqueness_of :username, case_sensitive: false
  validates_numericality_of :credits
  validates_numericality_of :minutes_played, greater_than_or_equal_to: 0


# Security

  attr_accessible :email,
                  :username,
                  :plan_id,
                  :password,
                  :password_confirmation

  attr_accessible :stripe_token,
                  :email_or_username,
                  :remember_me

# Plans

  def customer_description
    [safe_username, id].join('-')
  end

  def card?
    not card.nil?
  end

  def customer
    @customer ||= Stripe::Customer.retrieve(stripe_id) if stripe_id?
  end
  
  alias_method :customer?, :stripe_id?

  def create_customer
    options = {
      card: stripe_token,
      coupon: coupon,
      email: email,
      description: customer_description
    }

    @customer = Stripe::Customer.create(options)
    self.stripe_id = @customer.id

    # TODO: Document why this conitional helps
    if @customer.respond_to?(:active_card)
      build_card_from_stripe(@customer.active_card)
    end

    self.stripe_token = nil
  end

  def create_charge!(amount)
    create_customer unless customer?
    
    charge = Stripe::Charge.create(
      customer: stripe_id,
      amount: amount,
      currency: 'usd',
      description: "Minefold.com time"
    )

    create_card_from_stripe(charge.card)

    charge
  end

  def build_card_from_stripe(card)
    build_card Card.attributes_from_stripe(card)
  end

  def create_card_from_stripe(card)
    create_card Card.attributes_from_stripe(card)
  end


  def self.paid_for_minecraft?(username)
    response = RestClient.get "http://www.minecraft.net/haspaid.jsp", params: {user: username}
    return response == 'true'
  rescue RestClient::Exception
    return false
  end

  def buy_time!(pack)
    # The order is important here. If the charge fails for some reason we don't want the credits to be applied.
    create_charge! pack.amount
    increment_hours! pack.hours
  end
  

# Credits

  # Kicks off the audit trail for any credits the user starts off with
  after_create do
    CreditTrail.log(self, self.credits)
  end

  # TODO: MUST FIX
  def increment_hours!(n)
    increment_credits! self.class.hours_to_credits(n)
  end

  def increment_credits!(n)
    inc(:credits, n.to_i).tap { CreditTrail.log(self, n.to_i) }
  end
  
  def hours_left
    credits / User::BILLING_PERIOD
  end


# Authentication

  devise :registerable,
         :database_authenticatable,
         :recoverable,
         :rememberable,
         :trackable,
         :validatable

  def username=(str)
    super(str)
    self.safe_username = self.class.sanitize_username(str)
  end


# Avatars

  mount_uploader :avatar, AvatarUploader

  def fetch_avatar!
    self.remote_avatar_url = "http://minecraft.net/skin/#{safe_username}.png"
    # Minecraft doesn't store default skins so it raises a HTTPError
  rescue OpenURI::HTTPError
  end

  def async_fetch_avatar!
    Resque.enqueue(FetchAvatarJob, id)
  end

  before_save do
    async_fetch_avatar! if safe_username_changed?
  end  


# Other

  def worlds
    (created_worlds | whitelisted_worlds).sort_by do |world|
      world.creator.safe_username + world.name
    end
  end

  def current_world?(world)
    current_world == world
  end

  def to_param
    slug
  end

protected

  def self.find_for_database_authentication(conditions)
    login = conditions.delete(:email_or_username)
    by_email_or_username(login).first
  end

  def self.chris
    where(username: 'chrislloyd').cache.first
  end

  def self.dave
    where(username: 'whatupdave').cache.first
  end

private

  def self.sanitize_username(str)
    str.downcase.strip
  end

  def self.sanitize_email(str)
    str.downcase.strip
  end

  def self.hours_to_credits(n)
    n.hours / BILLING_PERIOD
  end

end
