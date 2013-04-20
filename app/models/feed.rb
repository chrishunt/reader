class Feed < ActiveRecord::Base
  include ActionView::Helpers::SanitizeHelper
  mount_uploader :document, FeedUploader
  has_one :feed_icon, :dependent => :destroy
  has_many :subscriptions, :dependent => :destroy
  has_many :entries, :dependent => :destroy
  belongs_to :user
  validates :feed_url, :uniqueness => true

  before_create :set_tokens, :strip_name
  before_save :scrub
  after_create :poll_feed, :get_icon
  scope :fetchable, where(:fetchable => true).where(:private => false)
  scope :unfetchable, where(:fetchable => false)
  #scope :suggested, where(:suggested => true)

  after_save :set_fetchable

  def set_fetchable
    if feed_errors > 5 || parse_errors > 5
      self.update_column(:fetchable, false)
    end
  end

  def self.suggested(uid)
    user = User.find uid
    fids = user.subscriptions.pluck(:feed_id)
    feeds = []
    self.where(:suggested => true).all.each do |f|
      feeds << f unless fids.include? f.id
    end
    feeds
  end

  def strip_name
    self.name.strip!
  end

  def scrub
    name = sanitize(name)
    description = sanitize(description)
  end

  def set_tokens
    self.token = rand(36**20).to_s(36)
    self.secret_token = rand(36**40).to_s(36)
  end

  def self.get_icons
    find_each do |f|
      f.get_icon
    end
  end

  def get_icon
    GetIcon.perform_async(id) if fetchable? && public?
  end

  def poll_feed
    PollFeed.perform_async(id) if fetchable? && public?
  end

  def push_enabled?
    hub.present? && topic.present?
  end

  def public?
    !private?
  end

  def save_document(body)
    file = FilelessIO.new(body)
    file.original_filename = "feed.xml"
    self.document = file
    self.save!
  end

end
