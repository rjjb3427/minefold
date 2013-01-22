require 'state_machine/core'
require './lib/redis_key'

class Server < ActiveRecord::Base
  extend StateMachine::MacroMethods

  attr_accessible :name, :description, :funpack_id, :shared, :settings

  acts_as_paranoid

  belongs_to :creator, class_name: 'User', :inverse_of => :created_servers

  validates_presence_of :party_cloud_id

  belongs_to :funpack
  validates_presence_of :funpack

  delegate :game, :to => :funpack

  has_and_belongs_to_many :watchers, class_name: 'User', uniq: true

  has_and_belongs_to_many :watchers,
    class_name: 'User',
    join_table: 'watchers',
    uniq: true

  has_and_belongs_to_many :starrers,
    class_name: 'User',
    join_table: 'stars',
    uniq: true

  has_many :memberships, :dependent => :destroy
  has_many :users, :through => :memberships

  validates_presence_of :name

  def initialize(*args, &blk)
    super
    self.settings = {}
  end

  has_many :votes, :dependent => :destroy

  def count_online_players
    PartyCloud.count_players_online(party_cloud_id)
  end


  serialize :settings, JSON

  has_many :posts, order: 'created_at DESC', :dependent => :destroy

  has_one :world, order: 'updated_at ASC', :dependent => :destroy

  has_many :sessions, :class_name => 'ServerSession' do

    def current
      active.first_or_initialize
    end

    def current?
      active.exists?
    end

  end

  States = {
    idle: 0,
    starting: 1,
    up: 2,
    stopping: 3
  }

  validates_presence_of :state

  state_machine :initial => :idle do

    States.each do |name, value|
      state(name, value: value)
    end

    event :start do
      transition all => :starting
    end

    event :started do
      transition all => :up
    end

    event :stop do
      transition all => :stopping
    end

    event :stopped do
      transition all => :idle
    end
  end

  def normal?
    not shared?
  end

  def address
    [host, port].compact.join(':')
  end

  # TODO remove this with new auth stuff
  before_create :whitelist_creator

  def whitelist_creator
    creator_account = creator.accounts.mojang.first

    creator_uid = creator_account ? creator_account.uid : creator.username

    settings['whitelist'] ||= creator_uid
    settings['ops'] ||= creator_uid
  end

  after_create :allocate_shared_host!

  def allocate_shared_host!
    if not host?
      self.host = [id, "fun-#{funpack.id}", 'us-east-1', 'foldserver', 'com'].join('.')
      self.save!
    end
  end

  def player_uids
    (settings['whitelist'] || '').split | (settings['ops'] || '').split
  end

  def redis_watchers_key
    RedisKey.new(self, :watchers).to_s
  end


  def activity_stream
    @activity_stream ||= ActivityStream.new(self, $redis)
  end

  after_create :create_activity

  def create_activity
    Activities::CreatedServer.publish(self)
  end

  after_create :add_creator_to_watchers

  def add_creator_to_watchers
    self.watchers << creator
  end

end
