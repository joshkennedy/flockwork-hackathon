class Project < ApplicationRecord
  include RefreshesDashboard
  include OrganizationOwnedBlobs

  NAME_MAX_LENGTH = 120
  belongs_to :organization

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
  TOOLS = TOOL_LABELS.keys.freeze

  belongs_to :owner, class_name: "Person"
  broadcasts_refreshes_to ->(project) { project }
  has_one :project_debrief, dependent: :destroy
  has_one :project_recurrence, dependent: :destroy
  has_one :project_occurrence, dependent: :nullify
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
  BANNER_MAX_PIXELS = 40_000_000
  BANNER_MAX_DIMENSION = 12_000
  # Target pixel sizes for each crop; the phone crop is a 2:1 shape for narrow screens.
  BANNER_SIZES = { wide: [ 1500, 500 ], phone: [ 800, 400 ] }.freeze
  # shortcut: a crop narrower than this is shown on a blurred fill instead of upscaled, revisit if banners get wider than 1000px
  BANNER_MIN_WIDTH = 1000

  has_one_attached :banner
  validates :banner_focus_x, :banner_focus_y, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :banner_alt_text, length: { maximum: 200 }
  validates_organization_owned_blobs attachments: [ :banner ]
  validate :banner_is_an_image_within_limits
  validate :banner_pixel_dimensions_within_limits

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

  # An archived or deleted Project's Public link answers as not found.
  scope :publicly_linked, -> { where(archived_at: nil, deleted_at: nil).where.not(public_token: nil) }

  normalizes :skills_needed, with: ->(skills) { Skills.normalize(skills) }

  has_many :invitations, dependent: :restrict_with_exception

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  validate :ends_on_is_not_before_starts_on
  validate :enabled_tools_are_known

  def active?
    done_at.nil? && archived_at.nil? && deleted_at.nil?
  end

  # [left, top, width, height] in source pixels: the largest crop at the target aspect that keeps the focal point in view.
  def banner_crop(kind)
    width, height = banner.blob.metadata.values_at("width", "height")
    aspect = BANNER_SIZES.fetch(kind).then { |w, h| w.fdiv(h) }
    if width.fdiv(height) > aspect
      crop_w = (height * aspect).round.clamp(1, width)
      [ (banner_focus_x * width - crop_w / 2.0).round.clamp(0, width - crop_w), 0, crop_w, height ]
    else
      crop_h = (width / aspect).round.clamp(1, height)
      [ 0, (banner_focus_y * height - crop_h / 2.0).round.clamp(0, height - crop_h), width, crop_h ]
    end
  end

  # False until the photo is analyzed and every variant the pages use is stored (see ProjectBannerVariantsJob), or
  # after a variant failed: the page shows no banner instead of decoding the photo during a request.
  def banner_ready?
    return false unless banner.attached?

    blob = banner.blob
    return false unless blob.analyzed? && blob.metadata["width"].present? && !blob.metadata["variants_failed"]

    digests = banner_variants.map { |variant| variant.variation.digest }
    blob.variant_records.where(variation_digest: digests).count == digests.size
  end

  # The model's alt text waits on the blob until a leader saves it as banner_alt_text.
  def banner_alt_suggestion
    banner.blob.metadata["alt_suggestion"] if banner.attached?
  end

  def reset_banner_focus
    self.banner_focus_x = 0.5
    self.banner_focus_y = 0.5
    self.banner_focus_manual = false
    self.banner_alt_text = nil
  end

  def banner_dimension_error_message_for(blob)
    width, height = blob.metadata.values_at("width", "height")
    return if width.blank? || height.blank?

    banner_dimension_limit_message if banner_dimensions_exceed?(width, height)
  end

  # The format is a string because a variation signed into a URL loses symbol values, which would change its digest
  # and make the first request for a pregenerated variant decode it again.
  def banner_variant(kind)
    banner.variant(crop: banner_crop(kind), resize_to_limit: BANNER_SIZES.fetch(kind), format: "webp", saver: { quality: 82 })
  end

  def banner_reposition_variant
    banner.variant(resize_to_limit: [ 2400, 2400 ], format: "webp")
  end

  def banner_variants
    [ banner_variant(:wide), banner_variant(:phone), banner_reposition_variant ]
  end

  def banner_small?
    banner_crop(:wide)[2] < BANNER_MIN_WIDTH
  end

  def enable_public_link!
    update!(public_token: generate_public_token)
  end

  def reset_public_link!
    revoke_with_banner_rotation!(public_token: generate_public_token)
  end

  def disable_public_link!
    revoke_with_banner_rotation!(public_token: nil)
  end

  def soft_delete!
    revoke_with_banner_rotation!(deleted_at: Time.current)
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

    def revoke_with_banner_rotation!(attributes)
      old_blob = banner.blob if banner.attached?
      # An analyzed banner with no dimensions can't be shown or validated again, so it is dropped instead of copied.
      new_blob = copy_banner_blob(old_blob) if old_blob && !(old_blob.analyzed? && old_blob.metadata.values_at("width", "height").any?(&:blank?))
      committed = false

      self.class.transaction do
        transaction = self.class.current_transaction
        if old_blob
          transaction.after_commit do
            committed = true
            old_blob.purge
            ProjectBannerVariantsJob.perform_later(self) if new_blob
          end
        end
        transaction.after_rollback { new_blob.purge } if new_blob

        new_blob ? banner.attach(new_blob) : banner.detach
        SignInChallenge.open.where(project: self).update_all(expires_at: Time.current)
        update!(attributes)
      end
    rescue StandardError
      new_blob&.purge unless committed || new_blob&.destroyed?
      raise
    end

    def copy_banner_blob(blob)
      blob.open do |file|
        ActiveStorage::Blob.create_and_upload!(
          io: file,
          filename: blob.filename,
          content_type: blob.content_type,
          metadata: blob.metadata.merge("organization_id" => organization_id),
          service_name: blob.service_name,
          identify: false
        )
      end
    end

    def banner_is_an_image_within_limits
      change = attachment_changes["banner"]
      return unless change.is_a?(ActiveStorage::Attached::Changes::CreateOne)

      errors.add(:banner, "must be a JPEG, PNG, WebP or HEIC image") unless banner_bytes_type(change.attachable).in?(BANNER_TYPES)
      errors.add(:banner, "must be 10 MB or smaller") if change.blob.byte_size > BANNER_MAX_BYTES
    end

    def banner_pixel_dimensions_within_limits
      change = attachment_changes["banner"]
      return unless change.is_a?(ActiveStorage::Attached::Changes::CreateOne)

      blob = change.blob
      return unless blob.analyzed?

      width, height = blob.metadata.values_at("width", "height")
      # An image libvips can't decode (HEIC without codec support, a corrupt file) would never get variants.
      return errors.add(:banner, "couldn't be read as an image. Try a JPEG or PNG") if width.blank? || height.blank?

      if banner_dimensions_exceed?(width, height)
        errors.add(:banner, banner_dimension_limit_message)
      end
    end

    def banner_dimensions_exceed?(width, height)
      width > BANNER_MAX_DIMENSION || height > BANNER_MAX_DIMENSION || width * height > BANNER_MAX_PIXELS
    end

    def banner_dimension_limit_message
      "must not exceed #{BANNER_MAX_DIMENSION} pixels per side or #{BANNER_MAX_PIXELS / 1_000_000} megapixels"
    end

    # Sniff the bytes ourselves: Active Storage keeps a declared type when it matches the file name, so a text file named .jpg would pass.
    def banner_bytes_type(attachable)
      return attachable.open { |io| Marcel::MimeType.for(io) } if attachable.is_a?(ActiveStorage::Blob)

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
