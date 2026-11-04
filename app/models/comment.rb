class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
  belongs_to :author, class_name: "Person"
  # Through another record that a cascade delete may already have removed, so nil-safe.
  after_commit -> { commentable&.project&.broadcast_refresh_later }
  has_many :mentions, as: :mentionable, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy

  has_rich_text :body

  validates :body, presence: true

  after_create :follow_author
  after_create :notify_followers
  after_save :parse_mentions

  delegate :project, to: :commentable

  private
    def follow_author
      commentable.follows.create_or_find_by!(person: author)
    end

    def notify_followers
      commentable.follows.includes(:person).find_each do |follow|
        Notifier.notify(
          recipient: follow.person,
          kind: "followed_reply",
          notifiable: self,
          actor: author
        )
      end
    end

    def parse_mentions
      MentionParser.new(self).call
    end
end
