class Note < ApplicationRecord
  include WorkspaceScoped

  VISIBILITY_LABELS = {
    "team" => "Team",
    "leaders" => "Leaders and Admins",
    "admins" => "Admins"
  }.freeze

  belongs_to :notable, polymorphic: true
  belongs_to :author, class_name: "Person", inverse_of: :authored_notes

  enum :visibility, { team: 0, leaders: 1, admins: 2 }, default: :team, validate: true

  before_validation :force_admin_visibility_for_person

  validates :body, presence: true
  validates :notable_type, inclusion: { in: %w[Project Recipient Person] }
  validate :author_belongs_to_workspace
  validate :notable_belongs_to_workspace

  def project
    case notable
    when Project then notable
    when Recipient then notable.project
    end
  end

  private
    def force_admin_visibility_for_person
      self.visibility = :admins if notable_type == "Person"
    end

    def notable_belongs_to_workspace
      notable_workspace_id = project&.workspace_id || (notable.workspace_id if notable.is_a?(Person))
      return if notable_workspace_id == workspace_id

      errors.add(:notable, "must belong to the same Workspace")
    end

    def author_belongs_to_workspace
      return if author&.workspace_id == workspace_id

      errors.add(:author, "must belong to the same Workspace")
    end
end
