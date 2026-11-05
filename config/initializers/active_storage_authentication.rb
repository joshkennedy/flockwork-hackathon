module ActiveStorageDirectUploadProtection
  extend ActiveSupport::Concern

  included do
    rate_limit to: 30, within: 1.hour, by: -> { Current.session.person_id }, name: "direct_uploads", only: :create, with: -> { head :too_many_requests }
    before_action :reject_oversized_direct_upload, only: :create
  end

  private
    def request_authentication
      head :unauthorized
    end

    def reject_oversized_direct_upload
      head :unprocessable_content if blob_args[:byte_size].to_i > Project::BANNER_MAX_BYTES
    end
end

Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.include(Authentication)
  ActiveStorage::DirectUploadsController.include(ActiveStorageDirectUploadProtection)
end
