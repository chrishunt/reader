class ItemValidator < ActiveModel::Validator
  def validate(record)
    user_id         = record.user_id
    entry_id        = record.entry_id
    subscription_id = record.subscription_id
    c = Item.where(:user_id => user_id).where(:entry_id => entry_id).where(:subscription_id => subscription_id).count
    if c >= 1 && record.id.nil?
      record.errors[:base] = "Already delivered"
    end
  end
end

class Item < ActiveRecord::Base
  belongs_to :user
  belongs_to :from, :class_name => "User"
  belongs_to :entry
  belongs_to :subscription
  has_many :comments, :dependent => :destroy

  belongs_to :parent, :class_name => "Item"
  has_many :children, :class_name => "Item", :foreign_key => :parent_id


  validates_with ItemValidator

  after_update :after_user_item_update

  delegate :url, :title, :to => :entry, :allow_nil => true

  default_scope {
    includes(:entry).includes(:comments)
  }

  scope :for, lambda { |user_id|
     where("user_id = ?", user_id)
  }

  scope :filter, lambda { |filter|
    unless filter == "all"
      where("#{filter} = ?", true)
    end
  }

  def feed
    raise "beans"
  end

  def after_user_item_update
    update_children
    share_item unless share_delivered?
    unshare_item if share_delivered?
  end

  def update_subscription_count
    UpdateSubscriptionCount.perform_async(subscription_id) if subscription && subscription.user == self.user
  end

  def active_model_serializer
    ItemSerializer
  end

  def share_item
    if self.shared and !self.share_delivered?
      self.update_column :share_delivered, true
      ShareItem.perform_async self.id
    end
  end

  def unshare_item
    if !self.shared and self.share_delivered?
      self.update_column :share_delivered, false
      UnshareItem.perform_async self.id
    end
  end

  def update_children
    if self.has_new_comments?
      UpdateDownstreamItems.perform_async self.id
    end
  end

  def post_to_twitter
    Singly.tweet_item(user, self)
  end

  def post_to_facebook
    Singly.facebook_item(user, self)
  end

  def all_comments
    (parent_comments + comments).sort do |a,b|
      a.created_at <=> b.created_at
    end
  end

  def parent_comments
    parent.try(:all_comments) || []
  end

  def self.batch_mark_read(ids)
    # half assed attempt at preventing a sql injection
    unless ids.nil?
      _ids = ids.collect do |id|
        id.to_i.to_s
      end
      self.where("id IN (#{_ids.join(',')})").all.each do |item|
        item.unread = false
        item.save
      end
    end
  end



end

