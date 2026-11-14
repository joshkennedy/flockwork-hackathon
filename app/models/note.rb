class Note < ApplicationRecord
  belongs_to :organization

  VISIBILITY_LABELS = {
    "team" => "Team",
    "leaders" => "Leaders and Admins",
    "admins" => "Admins"
  }.freeze

  belongs_to :notable, polymorphic: true
  belongs_to :author, class_name: "Person", inverse_of: :authored_notes
  after_commit -> { project&.broadcast_refresh_later }

  enum :visibility, { team: 0, leaders: 1, admins: 2 }, default: :team, validate: true

  before_validation :force_admin_visibility_for_person

  validates :body, presence: true
  validates :notable_type, inclusion: { in: %w[Project Recipient Person] }
  validate :author_belongs_to_organization
  validate :notable_belongs_to_organization

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

    def notable_belongs_to_organization
      notable_organization_id = project&.organization_id || (notable.organization_id if notable.is_a?(Person))
      return if notable_organization_id == organization_id

      errors.add(:notable, "must belong to the same church")
    end

    def author_belongs_to_organization
      return if author&.organization_id == organization_id

      errors.add(:author, "must belong to the same church")
    end
end
