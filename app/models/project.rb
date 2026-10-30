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
  has_many :schedule_items, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :slots, dependent: :destroy
  has_many :planner_sessions, dependent: :destroy
  has_many :budget_lines, dependent: :destroy
  has_many :recipients, dependent: :destroy
  has_many :notes, as: :notable, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy

  def budget_lines_by_kind(kind)
    budget_lines.public_send(kind).order(:id)
  end

  def budget_kind_totals(kind)
    lines = budget_lines_by_kind(kind).to_a
    {
      estimated_cents: BudgetLine.estimated_total_cents(lines),
      actual_cents: BudgetLine.actual_total_cents(lines)
    }
  end

  def budget_grand_totals
    lines = budget_lines.order(:id).to_a
    {
      estimated_cents: BudgetLine.estimated_total_cents(lines),
      actual_cents: BudgetLine.actual_total_cents(lines)
    }
  end

  has_many :messages, dependent: :destroy

  def message_board_roots
    messages.roots.includes(:author, :rich_text_body, replies: [ :author, :rich_text_body ])
      .order(created_at: :desc, id: :desc)
  end

  has_many :doc_items, dependent: :destroy

  has_many :lists, dependent: :destroy
  has_many :list_rows, through: :lists, source: :rows

  scope :active, -> { where(done_at: nil, archived_at: nil, deleted_at: nil) }

  has_many :invitations, dependent: :restrict_with_exception

  validates :name, presence: true
  validate :ends_on_is_not_before_starts_on
  validate :enabled_tools_are_known

  def active?
    done_at.nil? && archived_at.nil? && deleted_at.nil?
  end

  def enable_public_link!
    update!(public_token: generate_public_token)
  end

  def reset_public_link!
    update!(public_token: generate_public_token)
  end

  def disable_public_link!
    update!(public_token: nil)
  end

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
    def generate_public_token
      loop do
        token = SecureRandom.urlsafe_base64(24)
        break token unless self.class.exists?(public_token: token)
      end
    end

    def ends_on_is_not_before_starts_on
      return if starts_on.blank? || ends_on.blank? || ends_on >= starts_on

      errors.add(:ends_on, "must be on or after the start date")
    end

    def enabled_tools_are_known
      return if (enabled_tools - TOOLS).empty?

      errors.add(:enabled_tools, "contains an unknown Tool")
    end
end
