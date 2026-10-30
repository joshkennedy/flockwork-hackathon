class Message < ApplicationRecord
  belongs_to :project
  belongs_to :author, class_name: "Person"
  belongs_to :parent, class_name: "Message", optional: true
  has_many :replies, -> { order(created_at: :asc, id: :asc) }, class_name: "Message",
    foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent

  has_rich_text :body

  validates :body, presence: true
  validate :parent_must_be_root

  scope :roots, -> { where(parent_id: nil) }

  before_validation :attach_reply_to_root, on: :create

  private
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
