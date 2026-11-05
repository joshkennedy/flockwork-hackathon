Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.include(Authentication)
  ActiveStorage::DirectUploadsController.class_eval do
    private
      def request_authentication
        head :unauthorized
      end
  end
end
