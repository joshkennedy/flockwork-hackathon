class Workspace < ApplicationRecord
  # Slugs that would shadow top-level routes
  RESERVED_SLUGS = %w[oversight projects up workspaces].freeze

  has_many :projects, dependent: :destroy
  has_many :tasks, through: :projects
  has_many :notes, dependent: :destroy
  has_many :people, dependent: :destroy
  has_many :notifications, through: :people
  has_many :invitations, dependent: :restrict_with_exception

  encrypts :pco_app_id, :pco_secret

  normalizes :name, with: ->(name) { name.strip }
  before_validation :assign_slug, on: :create, if: -> { slug.blank? }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :overextended_limit, numericality: { only_integer: true, greater_than: 0 }

  def to_param
    slug
  end

  def planning_center_connected?
    pco_app_id.present? && pco_secret.present?
  end

  private
    def assign_slug
      base = name.to_s.parameterize.presence || "workspace"
      taken = RESERVED_SLUGS.include?(base) || Workspace.exists?(slug: base)
      self.slug = taken ? "#{base}-#{SecureRandom.hex(3)}" : base
    end
end
