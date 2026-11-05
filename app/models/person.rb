class Person < ApplicationRecord
  include RefreshesStaffingSuggestions
  include OrganizationScoped

  NOTIFICATION_CHANNELS = {
    "in_app" => :in_app_preferences,
    "email" => :email_preferences,
    "sms" => :sms_preferences
  }.freeze

  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :comments, foreign_key: :author_id, inverse_of: :author, dependent: :destroy
  has_many :follows, dependent: :destroy
  has_many :mentions, dependent: :destroy
  has_many :recipients, dependent: :destroy
  has_many :slot_claims, dependent: :destroy
  has_many :notes, as: :notable, dependent: :destroy
  has_many :unavailabilities, dependent: :destroy
  has_many :check_ins, dependent: :destroy
  has_many :logged_check_ins, class_name: "CheckIn", foreign_key: :checked_in_by_id, inverse_of: :checked_in_by, dependent: :nullify
  has_many :authored_notes, class_name: "Note", foreign_key: :author_id, inverse_of: :author,
    dependent: :restrict_with_exception
  has_many :projects, through: :memberships
  has_many :owned_projects, class_name: "Project", foreign_key: :owner_id, inverse_of: :owner
  has_many :assigned_tasks, class_name: "Task", foreign_key: :assignee_id, inverse_of: :assignee,
    dependent: :nullify
  has_many :completed_tasks, class_name: "Task", foreign_key: :completed_by_id, inverse_of: :completed_by,
    dependent: :nullify
  has_many :started_planner_sessions, class_name: "PlannerSession", foreign_key: :started_by_id,
    inverse_of: :started_by, dependent: :restrict_with_exception
  has_many :invitations, dependent: :restrict_with_exception
  has_many :sent_invitations, class_name: "Invitation", foreign_key: :inviter_id, inverse_of: :inviter,
    dependent: :restrict_with_exception
  has_many :notifications, foreign_key: :recipient_id, inverse_of: :recipient, dependent: :destroy
  has_many :acted_notifications, class_name: "Notification", foreign_key: :actor_id, inverse_of: :actor,
    dependent: :nullify

  generates_token_for :sign_in, expires_in: 15.minutes do
    [ last_signed_in_at, email ]
  end

  # Bound to pending_email, so confirming (which clears it) or asking for a different address voids the link.
  generates_token_for :email_change, expires_in: 24.hours do
    pending_email
  end

  # Every typed word must appear somewhere in the name, so "ma lo" finds Maria Lopez.
  scope :matching, ->(query) {
    query.to_s.split.first(5).reduce(all) { |people, word| people.where("people.name ILIKE ?", "%#{sanitize_sql_like(word)}%") }
  }

  # Quick filters on the People directory. Oversight shares never_asked, so both use one rule.
  scope :serving_now, -> { where(id: Membership.joins(:project).merge(Project.active).select(:person_id)) }
  scope :leading, -> { where(id: Membership.leader.joins(:project).merge(Project.active).select(:person_id)) }
  scope :away_on, ->(date = Date.current) { where(id: Unavailability.covering(date).select(:person_id)) }
  scope :without_email, -> { where(email: [ nil, "" ]) }
  # Invitations and ownership preserve Team history after Membership deletion; soft-deleted Projects retain Memberships.
  # Admins already lead the church, so listing them as not yet invited would misstate their involvement.
  # Recipients are being cared for by a Project, even on deleted Projects and without Team history.
  scope :never_asked, -> { where(admin: false).where.missing(:invitations, :memberships, :owned_projects, :recipients) }

  normalizes :email, with: ->(email) { email.strip.downcase.presence }
  normalizes :pending_email, with: ->(email) { email.strip.downcase.presence }
  normalizes :phone, with: ->(phone) {
    value = phone.strip
    (value.start_with?("+") ? value.gsub(/[ ()\-.]/, "") : value).presence
  }
  normalizes :skills, with: ->(skills) { Skills.normalize(skills) }

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :email, uniqueness: { scope: :organization_id }, allow_nil: true
  # The first Admin of a new Organization must be able to sign in, so they need an email then.
  validates :email, presence: true, on: :organization_creation
  validates :pending_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validate :pending_email_not_taken, if: :pending_email_changed?
  validate :cannot_remove_last_admin, if: :admin_changed?
  validate :sms_requires_international_phone

  # Signing in consumes a link by stamping last_signed_in_at, which invalidates every link issued before it.
  # The conditional update means two simultaneous uses of one link cannot both succeed.
  def self.sign_in_with_token(token)
    person = find_by_token_for(:sign_in, token)
    return unless person

    updated = where(id: person.id, last_signed_in_at: person.last_signed_in_at)
      .update_all(last_signed_in_at: Time.current)
    person if updated == 1
  end

  # An address typed by an Admin only becomes the sign-in email once its owner follows the mailed link.
  # Uniqueness is checked again here, because someone else may have taken the address while the link sat unread.
  def self.confirm_email_change(token)
    person = find_by_token_for(:email_change, token)
    return unless person

    person if person.update(email: person.pending_email, pending_email: nil)
  end

  def can_sign_in?
    email.present?
  end

  def email_for?(kind)
    notification_for?("email", kind)
  end

  def notification_for?(channel, kind)
    kind = kind.to_s
    settings = Notification::KINDS.fetch(kind)
    preferences = public_send(NOTIFICATION_CHANNELS.fetch(channel.to_s))
    return ActiveModel::Type::Boolean.new.cast(preferences[kind]) if preferences.key?(kind)

    channel.to_s == "email" ? settings.fetch(:email_default) : channel.to_s == "in_app"
  end

  def sms_phone?
    /\A\+[1-9]\d{6,14}\z/.match?(phone.to_s)
  end

  private
    def pending_email_not_taken
      return unless pending_email && organization.people.where.not(id:).exists?(email: pending_email)

      errors.add(:email, "has already been taken")
    end

    def sms_requires_international_phone
      return unless Notification::KINDS.keys.any? { |kind| notification_for?("sms", kind) }
      return if sms_phone?

      errors.add(:phone, "must include the country code, such as +12025550100, to receive SMS notifications")
    end

    def cannot_remove_last_admin
      return if admin?
      return if organization.people.where(admin: true).where.not(id:).exists?

      errors.add(:admin, "cannot be removed from the last Admin in the Organization")
    end
end
