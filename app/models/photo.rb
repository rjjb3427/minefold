class Photo
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Slug
  include Mongoid::Paranoia

  default_scope order_by([:created_at, :asc])

  mount_uploader :file, PhotoUploader

  belongs_to :creator, class_name: 'User'

  field :title, type: String
  slug :title, index: true
  attr_accessible :title

  field :desc, type: String
  attr_accessible :desc

  field :sha, type: String, index: true

  field :published, type: Boolean
  scope :published, where(public: true)
  scope :pending, where(:public.exists => false)
  attr_accessible :published


  field :pageviews, type: Integer, default: 0
  validates_numericality_of :pageviews,
    only_integer: true,
    greater_than_or_equal_to: 0

  field :width, type: Integer
  field :height, type: Integer

  field :thumb_width, type: Integer
  field :thumb_height, type: Integer

  scope :recent, published.order_by([:created_at, :desc]).limit(12)

  def to_param
    id.to_param
  end

end
