class Message < ApplicationRecord
  belongs_to :project
  belongs_to :author, class_name: "Person"
  belongs_to :parent, class_name: "Message", optional: true
  has_many :replies, -> { order(created_at: :asc, id: :asc) }, class_name: "Message",
    foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :follows, as: :followable, dependent: :destroy
  has_many :mentions, as: :mentionable, dependent: :destroy

  has_rich_text :body

  validates :body, presence: true
  validate :parent_must_be_root

  scope :roots, -> { where(parent_id: nil) }

  before_validation :attach_reply_to_root, on: :create
  after_create :follow_author
  after_save :parse_mentions

  private
    def follow_author
      (parent || self).follows.create_or_find_by!(person: author)
    end

    def parse_mentions
      MentionParser.new(self).call
    end

    def attach_reply_to_root
      return if parent.nil?

      root = parent
      root = root.parent while root.parent_id.present?
      self.parent = root
    end

    def parent_must_be_root
      return if parent_id.nil?
      return if parent.parent_id.nil?

      errors.add(:parent, "must be a root message")
    end
end
