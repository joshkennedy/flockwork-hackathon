# Stores every banner variant the pages use, so no public request has to decode the photo.
class ProjectBannerVariantsJob < ApplicationJob
  queue_as :default

  def perform(project)
    return unless project.banner.attached?

    blob = project.banner.blob
    return unless blob.analyzed? && blob.metadata["width"].present? && !blob.metadata["variants_failed"]

    project.banner_variants.each(&:processed)
    project.touch
  rescue StandardError => error
    # Remembered on the blob, so pages skip the banner instead of retrying the decode on every request.
    blob&.update!(metadata: blob.metadata.merge("variants_failed" => true))
    Rails.logger.warn("Banner variants failed for project #{project.id}: #{error.class}: #{error.message}")
  end
end
