class Person < ApplicationRecord
  include WorkspaceScoped

  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :recipients, dependent: :destroy
  has_many :projects, through: :memberships
  has_many :owned_projects, class_name: "Project", foreign_key: :owner_id, inverse_of: :owner
  has_many :assigned_tasks, class_name: "Task", foreign_key: :assignee_id, inverse_of: :assignee,
    dependent: :nullify
  has_many :completed_tasks, class_name: "Task", foreign_key: :completed_by_id, inverse_of: :completed_by,
    dependent: :nullify
  has_many :invitations, dependent: :restrict_with_exception
  has_many :sent_invitations, class_name: "Invitation", foreign_key: :inviter_id, inverse_of: :inviter,
    dependent: :restrict_with_exception

  generates_token_for :sign_in, expires_in: 15.minutes do
    last_signed_in_at
  end

  normalizes :email, with: ->(email) { email.strip.downcase.presence }

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :email, uniqueness: { scope: :workspace_id }, allow_nil: true
  # The first Admin of a new Workspace must be able to sign in, so they need an email then.
  validates :email, presence: true, on: :workspace_creation
  validate :cannot_remove_last_admin, if: :admin_changed?

  # Signing in consumes a link by stamping last_signed_in_at, which invalidates every link issued before it.
  # The conditional update means two simultaneous uses of one link cannot both succeed.
  def self.sign_in_with_token(token)
    person = find_by_token_for(:sign_in, token)
    return unless person

    updated = where(id: person.id, last_signed_in_at: person.last_signed_in_at)
      .update_all(last_signed_in_at: Time.current)
    person if updated == 1
  end

  def can_sign_in?
    email.present?
  end

  private
    def cannot_remove_last_admin
      return if admin?
      return if workspace.people.where(admin: true).where.not(id:).exists?

      errors.add(:admin, "cannot be removed from the last Admin in the Workspace")
    end
end
