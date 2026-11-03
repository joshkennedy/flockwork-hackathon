class Project < ApplicationRecord
  include OrganizationScoped

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

  BANNER_TYPES = %w[ image/jpeg image/png image/webp image/heic image/heif ].freeze
  BANNER_MAX_BYTES = 10.megabytes
  # Target pixel sizes for each crop; the phone crop is a 2:1 shape for narrow screens.
  BANNER_SIZES = { wide: [ 1500, 500 ], phone: [ 800, 400 ] }.freeze
  # shortcut: a crop narrower than this is shown on a blurred fill instead of upscaled, revisit if banners get wider than 1000px
  BANNER_MIN_WIDTH = 1000

  has_one_attached :banner
  validates :banner_focus_x, :banner_focus_y, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :banner_alt_text, length: { maximum: 200 }
  validate :banner_is_an_image_within_limits

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

  # [left, top, width, height] in source pixels: the largest crop at the target aspect that keeps the focal point in view.
  def banner_crop(kind)
    width, height = analyzed_banner_blob.metadata.values_at("width", "height")
    aspect = BANNER_SIZES.fetch(kind).then { |w, h| w.fdiv(h) }
    if width.fdiv(height) > aspect
      crop_w = (height * aspect).round
      [ (banner_focus_x * width - crop_w / 2.0).round.clamp(0, width - crop_w), 0, crop_w, height ]
    else
      crop_h = (width / aspect).round
      [ 0, (banner_focus_y * height - crop_h / 2.0).round.clamp(0, height - crop_h), width, crop_h ]
    end
  end

  # False when the photo could not be analyzed (no dimensions), so the page shows no banner instead of failing.
  def banner_ready?
    return false unless banner.attached?

    analyzed_banner_blob.metadata["width"].present?
  end

  def reset_banner_focus
    self.banner_focus_x = 0.5
    self.banner_focus_y = 0.5
    self.banner_focus_manual = false
    self.banner_alt_text = nil
  end

  def banner_variant(kind)
    banner.variant(crop: banner_crop(kind), resize_to_limit: BANNER_SIZES.fetch(kind), format: :webp, saver: { quality: 82 })
  end

  def banner_small?
    banner_crop(:wide)[2] < BANNER_MIN_WIDTH
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
    project = creator.organization.projects.build(attributes.merge(owner: creator))

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

    def banner_is_an_image_within_limits
      change = attachment_changes["banner"]
      return unless change.is_a?(ActiveStorage::Attached::Changes::CreateOne)

      errors.add(:banner, "must be a JPEG, PNG, WebP, or HEIC image") unless banner_bytes_type(change.attachable).in?(BANNER_TYPES)
      errors.add(:banner, "must be 10 MB or smaller") if change.blob.byte_size > BANNER_MAX_BYTES
    end

    # Sniff the bytes ourselves: Active Storage keeps a declared type when it matches the file name, so a text file named .jpg would pass.
    def analyzed_banner_blob
      banner.blob.tap { |blob| blob.analyze unless blob.analyzed? }
    end

    def banner_bytes_type(attachable)
      io = attachable.is_a?(Hash) ? attachable[:io] : attachable
      io = io.tempfile if io.respond_to?(:tempfile)
      return unless io.respond_to?(:read)

      io.rewind
      Marcel::MimeType.for(io).tap { io.rewind }
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
