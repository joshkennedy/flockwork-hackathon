class DocItem < ApplicationRecord
  include OrganizationOwnedBlobs

  FILE_MAX_BYTES = 25.megabytes

  belongs_to :project
  belongs_to :author, class_name: "Person"
  broadcasts_refreshes_to :project
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :follows, as: :followable, dependent: :destroy

  has_rich_text :body
  has_one_attached :file

  enum :kind, { document: 0, file: 1, link: 2 }, validate: true

  validates :title, presence: true
  validates_organization_owned_blobs attachments: [ :file ], rich_texts: [ :body ]
  validate :validate_kind_specific_fields
  validate :file_is_within_size_limit

  scope :ordered, -> { order(:kind, :title, :id) }

  def pco?
    return false unless link?
    return false if url.blank?

    host = URI.parse(url).host&.downcase
    return false if host.blank?

    pco_host?(host)
  rescue URI::InvalidURIError
    false
  end

  private
    def validate_kind_specific_fields
      case kind
      when "document"
        errors.add(:body, "can't be blank") if body.blank?
      when "file"
        errors.add(:file, "must be attached") unless file.attached?
      when "link"
        if url.blank?
          errors.add(:url, "can't be blank")
        elsif !http_url?(url)
          errors.add(:url, "must be an http or https URL")
        end
      end
    end

    def file_is_within_size_limit
      return unless file? && file.attached? && file.blob.byte_size > FILE_MAX_BYTES

      errors.add(:file, "must be 25 MB or smaller")
    end

    def http_url?(value)
      uri = URI.parse(value)
      uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      false
    end

    def pco_host?(host)
      return true if host == "planning.center" || host.end_with?(".planning.center")
      return true if host == "planningcenteronline.com" || host.end_with?(".planningcenteronline.com")

      false
    end
end
