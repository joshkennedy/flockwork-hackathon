module ActiveStorageDirectUploadProtection
  extend ActiveSupport::Concern

  included do
    rate_limit to: 30, within: 1.hour, by: -> { Current.session.person_id }, name: "direct_uploads", only: :create, with: -> { head :too_many_requests }
    before_action :reject_oversized_direct_upload, only: :create
    before_action :stamp_blob_organization, only: :create
  end

  private
    def request_authentication
      head :unauthorized
    end

    def reject_oversized_direct_upload
      head :unprocessable_content if blob_args[:byte_size].to_i > Project::BANNER_MAX_BYTES
    end

    def stamp_blob_organization
      params[:blob][:metadata] = params[:blob].fetch(:metadata, {}).merge("organization_id" => Current.organization.id)
    end
end

# Rails verifies signed_blob_id and variation_key separately, so an anonymous visitor could pair a public blob with any
# variation and force a decode. Without a session, only variants that are already stored are served.
module ActiveStorageStoredVariantsOnly
  private
    def set_representation
      return super if cookies.signed[:session_id] && Session.exists?(id: cookies.signed[:session_id])

      representation = @blob.representation(params[:variation_key])
      stored = representation.respond_to?(:image) && representation.image&.attached?
      return head :not_found if !stored || @blob.metadata["variants_failed"]

      super
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      head :not_found
    end
end

Rails.application.config.to_prepare do
  ActiveStorage::Representations::BaseController.prepend(ActiveStorageStoredVariantsOnly)
  ActiveStorage::DirectUploadsController.include(Authentication)
  ActiveStorage::DirectUploadsController.include(ActiveStorageDirectUploadProtection)
end

# Direct uploads keep the client-claimed type until attach; never serve unverified bytes inline.
module ActiveStorageServeOnlyIdentifiedInline
  private
    def allowed_inline?
      super && identified?
    end
end

ActiveSupport.on_load(:active_storage_blob) { prepend ActiveStorageServeOnlyIdentifiedInline }
