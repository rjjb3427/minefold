class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Slug
  include Mongoid::Paranoia

  BILLING_PERIOD = 1.minute
  FREE_HOURS  = 4

  REFERRAL_CODE_LENGTH = 6
  REFERRAL_HOURS = 2

  field :email,          type: String
  field :username,       type: String
  field :safe_username,  type: String
  slug  :username,       index: true

  field :host,           default: 'pluto.minefold.com'

  field :credits,        type: Integer, default: (FREE_HOURS.hours / BILLING_PERIOD)
  field :minutes_played, type: Integer, default: 0
  embeds_many :credit_events

  attr_accessor :stripe_token
  attr_accessor :coupon

  field :stripe_id,       type: String
  field :plan_id,         type: String

  embeds_one :card

  field :referral_code,   type: String, default: -> {
    begin
      c = rand(36 ** REFERRAL_CODE_LENGTH).to_s(36).rjust(REFERRAL_CODE_LENGTH, '0').upcase
    end while self.class.where(code: c).exists?
    c
  }
  validates_uniqueness_of :referral_code


  STATUSES = %W(signed_up played payed)
  field :referral_state, default: 'signed_up'

  belongs_to :current_world, class_name: 'World', inverse_of: nil
  has_many :created_worlds, class_name: 'World', inverse_of: :creator

  has_and_belongs_to_many :whitelisted_worlds,
                          inverse_of: :whitelisted_players,
                          class_name: 'World'
  attr_accessor :email_or_username

  # FREE_HOURS = Plan.free.hours

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

  index :plan_id
  scope :by_plan_id, ->(plan_id) {
    where(plan_id: plan_id)
  }


# Validations

  validates_presence_of :username
  validates_uniqueness_of :email, case_sensitive: false
  validates_uniqueness_of :username, case_sensitive: false
  validates_confirmation_of :password
  validates_numericality_of :credits
  validates_numericality_of :minutes_played, greater_than_or_equal_to: 0
  # validates_inclusion_of :plan, in: Plan.stripe_ids, allow_blank: true


# Security

  attr_accessible :email,
                  :username,
                  :password,
                  :password_confirmation

  attr_accessible :stripe_token,
                  :email_or_username,
                  :remember_me

# Plans

  def casual?
    not plan_id?
  end

  def customer?
    stripe_id?
  end

  def customer_description
    [id, safe_username].join('-')
  end

  def card?
    not card.nil?
  end

  def customer
    @customer ||= Stripe::Customer.retrieve(stripe_id) if customer?
  end

  def create_customer
    @customer = Stripe::Customer.create email: email,
                                  description: customer_description,
                                         plan: plan_id,
                                       coupon: coupon,
                                         card: stripe_token
    self.stripe_id = @customer.id
    build_card_from_stripe(@customer.active_card)
    self.stripe_token = nil
  end

  def update_subscription
    if plan_id?
      subscription = customer.update_subscription(
        plan: plan_id,
        coupon: coupon,
        card: stripe_token,
        prorate: false
      )

      if not stripe_token.nil?
        build_card_from_stripe!(subscription.card)
      end

      subscription
    else
      customer.cancel_subscription
    end
  end

  before_save do
    if plan_id_changed?
      if customer?
        update_subscription
      else
        create_customer
      end
    end
  end

  def create_charge!(amount)
    charge = Stripe::Charge.create(
      amount: amount,
      currency: 'usd',
      customer: stripe_id,
      card: stripe_token,
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



# CREDITS

  # Kicks off the audit trail for any credits the user starts off with
  before_create do
    self.credit_events.build(delta: self.credits)
  end

  def increment_hours!(n, time=Time.now.utc)
    increment_credits! self.class.hours_to_credits(n), time
  end

  def increment_credits!(n, time=Time.now.utc)
    event = CreditEvent.new(delta: n.to_i, created_at: time)

    self.class.collection.update({_id: id}, {
      '$inc' => {credits: n.to_i},
      '$push' => {credit_events: event.attributes}
    })
  end

  def plan_credits
    Plan.find(plan).credits
  end

  def referral_credits
    cr = REFERRAL_HOURS.hours / BILLING_PERIOD
    (referrer.nil? ? 0 : cr) + (referrals.empty? ? 0 : referrals.length * cr)
  end


  def total_credits
    plan_credits + referral_credits
  end

  def hours_left
    credits / User::BILLING_PERIOD
  end


# AUTHENTICATION

  devise :registerable,
         :database_authenticatable,
         :recoverable,
         :rememberable,
         :trackable,
         :validatable

  def first_sign_in?
    sign_in_count <= 1
  end

  def username=(str)
    super(str)
    self.safe_username = self.class.sanitize_username(str)
  end


# AVATARS

  mount_uploader :avatar, AvatarUploader

  def fetch_avatar!
    self.remote_avatar_url = "http://minecraft.net/skin/#{safe_username}.png"
  rescue OpenURI::HTTPError # User has a default skin
  end

  def async_fetch_avatar!
    Resque.enqueue(FetchAvatar, id)
  end

  before_save do
    async_fetch_avatar! if safe_username_changed?
  end

# REFERRALS

  belongs_to :referrer,  class_name: 'User', inverse_of: :referrals
  has_many   :referrals, class_name: 'User', inverse_of: :referrer

  def played!
    self.referral_state = 'played'
    save!
  end

# USER_REFERRAL_BONUS = 1.hour
# FRIEND_REFERRAL_BONUS = 4.hours
#
# def referrals_left?
#   referrals.length < total_referrals
# end
#
# def referrals_left
#   total_referrals - referrals.length
# end

#   def verify!
#     decrement referrals: 1
#     invite.set claimed: true
#
#     add_credits USER_REFERRAL_BONUS
#     invite.creator.add_credits FRIEND_REFERRAL_BONUS
#   end

# OTHER

  def worlds
    (created_worlds | whitelisted_worlds).sort_by do |world|
      world.creator.safe_username + world.name
    end
  end

  def first_sign_in?
    sign_in_count <= 1
  end

  def to_param
    slug
  end

  def as_json(options={})
    {
      avatar_head_24_url: avatar.head.s24.url,
      avatar_head_60_url: avatar.head.s60.url,
      id: id
    }.merge(super(options))
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
