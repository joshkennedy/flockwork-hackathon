class Task < ApplicationRecord
  include RefreshesDashboard
  include OrganizationOwnedBlobs
  belongs_to :project
  belongs_to :assignee, class_name: "Person", optional: true
  belongs_to :completed_by, class_name: "Person", optional: true
  broadcasts_refreshes_to :project
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :follows, as: :followable, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy

  has_rich_text :details

  validates :title, presence: true
  validates_organization_owned_blobs rich_texts: [ :details ]
  validate :assignee_is_a_team_member

  scope :open, -> { where(completed_at: nil) }
  scope :done, -> { where.not(completed_at: nil) }
  scope :due_first, -> { order(Arel.sql("due_on ASC NULLS LAST"), :id) }

  private
    def assignee_is_a_team_member
      return if assignee_id.blank? || project.blank?
      return if project.memberships.exists?(person_id: assignee_id)

      errors.add(:assignee, "must be a Team member")
    end
end
