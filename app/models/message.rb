class Message < ApplicationRecord
  include OrganizationOwnedBlobs

  belongs_to :project
  belongs_to :author, class_name: "Person"
  belongs_to :parent, class_name: "Message", optional: true
  broadcasts_refreshes_to :project
  has_many :replies, -> { order(created_at: :asc, id: :asc) }, class_name: "Message",
    foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :follows, as: :followable, dependent: :destroy
  has_many :mentions, as: :mentionable, dependent: :destroy

  has_rich_text :body

  validates :body, presence: true
  validates_organization_owned_blobs rich_texts: [ :body ]
  validate :parent_must_belong_to_project
  validate :parent_must_be_root

  scope :roots, -> { where(parent_id: nil) }

  # Only a new thread goes to the whole Team; a reply would otherwise ping everyone on every turn.
  def notify_team
    return if parent_id.present?

    mentioned_person_ids = mentions.pluck(:person_id)
    project.memberships.includes(:person).find_each do |membership|
      next if membership.person_id.in?(mentioned_person_ids)

      Notifier.notify(
        recipient: membership.person,
        kind: "project_message",
        notifiable: self,
        actor: author
      )
    end
  end

  before_validation :attach_reply_to_root, on: :create
  after_create :follow_author
  after_create :parse_mentions
  after_update :parse_mentions_without_notifications

  private
    def follow_author
      (parent || self).follows.create_or_find_by!(person: author)
    end

    def parse_mentions
      MentionParser.new(self).call
    end

    def parse_mentions_without_notifications
      MentionParser.new(self, notify: false).call
    end

    def attach_reply_to_root
      return if parent.nil?

      root = parent
      root = root.parent while root.parent_id.present?
      self.parent = root
    end

    def parent_must_be_root
      return if parent_id.nil?
      return if parent.nil?
      return if parent.parent_id.nil?

      errors.add(:parent, "must be a root message")
    end

    def parent_must_belong_to_project
      return if parent_id.nil?

      if parent.nil?
        errors.add(:parent, "must exist")
      elsif parent.project_id != project_id
        errors.add(:parent, "must belong to the same project")
      end
    end
end
