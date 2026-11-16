class ProjectBannerFocusJob < ApplicationJob
  queue_as :default

  def perform(project, blob_id)
    suggest_focus(project, blob_id)
    # The crops depend on the focal point, so the variants are stored only once it is final.
    ProjectBannerVariantsJob.perform_later(project)
  end

  private
    # Best effort: any failure leaves the banner at its center focus, which a person can always change.
    def suggest_focus(project, blob_id)
      blob = ActiveStorage::Blob.find_by(id: blob_id)
      return unless blob
      return if ENV["OPENROUTER_API_KEY"].blank?
      return unless DemoAiLimit.allow?(project.organization)

      suggestion = ProjectBannerVision.call(blob)
      return unless suggestion

      project.with_lock do
        next unless project.banner.attached? && project.banner.blob_id == blob.id

        focus = project.banner_focus_manual? ? {} : { banner_focus_x: suggestion[:focus_x], banner_focus_y: suggestion[:focus_y] }
        project.update!(focus)
        blob.update!(metadata: blob.metadata.merge("alt_suggestion" => suggestion[:alt])) if suggestion[:alt].present? && project.banner_alt_text.blank?
      end
    rescue StandardError => error
      Rails.logger.warn("Banner focus suggestion failed for project #{project.id}: #{error.class}: #{error.message}")
    end
end
