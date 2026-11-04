class Organization < ApplicationRecord
  # Slugs that would shadow top-level routes
  RESERVED_SLUGS = %w[oversight projects up organizations settings].freeze
  DEFAULT_MARK_COLOR = "#D69000"
  # Every preset clears 2.5:1 on the page background, so the lead bird stays visible.
  MARK_PRESETS = {
    "Deep sunlit" => DEFAULT_MARK_COLOR,
    "Copper" => "#D4731C",
    "Clay" => "#C8502A",
    "Berry" => "#C42E5C",
    "Teal" => "#0E8C86",
    "Forest" => "#2F8A55",
    "Cobalt" => "#2D63D8"
  }.freeze

  has_many :projects, dependent: :destroy
  has_many :tasks, through: :projects
  has_many :notes, dependent: :destroy
  has_many :people, dependent: :destroy
  has_many :notifications, through: :people
  has_many :invitations, dependent: :restrict_with_exception

  encrypts :pco_app_id, :pco_secret

  normalizes :pco_skills_field_id, with: ->(value) { value.to_s.strip.presence }
  validates :pco_skills_field_id, format: { with: /\A[1-9]\d{0,19}\z/, message: "must be a numeric Planning Center custom field ID" }, allow_nil: true

  normalizes :name, with: ->(name) { name.strip }
  normalizes :mark_color, with: ->(color) { color.strip.upcase.delete_prefix("#").prepend("#") }
  before_validation :assign_slug, on: :create, if: -> { slug.blank? }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :mark_color, format: { with: /\A#\h{6}\z/, message: "must be a hex color like #D69000" }
  validates :overextended_limit, numericality: { only_integer: true, greater_than: 0 }

  def to_param
    slug
  end

  def planning_center_connected?
    pco_app_id.present? && pco_secret.present?
  end

  private
    def assign_slug
      base = name.to_s.parameterize.presence || "organization"
      taken = RESERVED_SLUGS.include?(base) || Organization.exists?(slug: base)
      self.slug = taken ? "#{base}-#{SecureRandom.hex(3)}" : base
    end
end
