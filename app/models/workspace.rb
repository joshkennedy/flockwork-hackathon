class Workspace < ApplicationRecord
  # Slugs that would shadow top-level routes
  RESERVED_SLUGS = %w[projects up workspaces].freeze

  has_many :projects, dependent: :destroy
  has_many :people, dependent: :destroy
  has_many :invitations, dependent: :restrict_with_exception

  normalizes :name, with: ->(name) { name.strip }
  before_validation :assign_slug, on: :create, if: -> { slug.blank? }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }

  def to_param
    slug
  end

  private
    def assign_slug
      base = name.to_s.parameterize.presence || "workspace"
      taken = RESERVED_SLUGS.include?(base) || Workspace.exists?(slug: base)
      self.slug = taken ? "#{base}-#{SecureRandom.hex(3)}" : base
    end
end
