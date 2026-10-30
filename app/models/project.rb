class Project < ApplicationRecord
  include WorkspaceScoped

  TOOLS = %w[tasks schedule signup_sheet budget recipients messages docs list].freeze
  TOOL_LABELS = {
    "tasks" => "Tasks",
    "schedule" => "Schedule",
    "signup_sheet" => "Sign-up sheet",
    "budget" => "Budget",
    "recipients" => "Recipients",
    "messages" => "Messages",
    "docs" => "Docs & Files",
    "list" => "List"
  }.freeze

  belongs_to :owner, class_name: "Person"
  has_many :memberships, dependent: :destroy
  has_many :people, through: :memberships

  validates :name, presence: true
  validate :ends_on_is_not_before_starts_on
  validate :enabled_tools_are_known

  def self.create_for(creator:, attributes:)
    project = creator.workspace.projects.build(attributes.merge(owner: creator))

    transaction do
      unless project.save
        raise ActiveRecord::Rollback
      end

      project.memberships.create!(person: creator, role: :leader)
    end

    project
  end

  private
    def ends_on_is_not_before_starts_on
      return if starts_on.blank? || ends_on.blank? || ends_on >= starts_on

      errors.add(:ends_on, "must be on or after the start date")
    end

    def enabled_tools_are_known
      return if (enabled_tools - TOOLS).empty?

      errors.add(:enabled_tools, "contains an unknown Tool")
    end
end
