class ProjectBannersController < ApplicationController
  before_action :set_project
  before_action :authorize_banner
  rate_limit to: 10, within: 1.hour, by: -> { ai_rate_limit_key }, name: "banner_upload",
    only: :update, if: :banner_upload?, with: :banner_upload_rate_limited

  def update
    upload = params.dig(:project, :banner)
    if upload.present?
      return head :unprocessable_content unless upload.is_a?(ActionDispatch::Http::UploadedFile)

      replace_banner(upload)
    else
      update_focus
    end
  end

  def destroy
    @project.banner.purge
    @project.reset_banner_focus
    @project.save!
    redirect_to @project
  end

  private
    def banner_upload?
      params.dig(:project, :banner).present?
    end

    def banner_upload_rate_limited
      redirect_to @project, alert: "Too many banner uploads. Try again in an hour.", status: :see_other
    end

    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def authorize_banner
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :update, @project)
    end

    def replace_banner(upload)
      if upload.size > Project::BANNER_MAX_BYTES
        redirect_to @project, alert: "The banner couldn't be saved: Banner must be 10 MB or smaller."
        return
      end

      blob = ActiveStorage::Blob.create_and_upload!(
        io: upload,
        filename: upload.original_filename,
        content_type: upload.content_type,
        metadata: { "organization_id" => Current.organization.id }
      )
      blob.analyze
      if (message = @project.banner_dimension_error_message_for(blob))
        blob.purge
        redirect_to @project, alert: "The banner couldn't be saved: Banner #{message}."
        return
      end

      @project.banner = blob
      @project.reset_banner_focus
      if @project.save
        ProjectBannerFocusJob.perform_later(@project, @project.banner.blob_id)
        redirect_to @project
      else
        blob.purge
        redirect_to @project, alert: "The banner couldn't be saved: #{@project.errors.full_messages.to_sentence}."
      end
    end

    def update_focus
      raise ActiveRecord::RecordNotFound unless @project.banner.attached?

      # Alt text and focus save separately: a save that only sends one of them leaves the other alone.
      attributes = params.expect(project: [ :banner_focus_x, :banner_focus_y, :banner_alt_text ])
      attributes[:banner_focus_manual] = true if attributes.key?(:banner_focus_x) || attributes.key?(:banner_focus_y)
      attributes[:banner_alt_text] = attributes[:banner_alt_text].presence if attributes.key?(:banner_alt_text)
      @project.assign_attributes(attributes)
      if @project.save
        # Saving the field, even cleared, answers the suggestion.
        blob = @project.banner.blob
        blob.update!(metadata: blob.metadata.except("alt_suggestion")) if attributes.key?(:banner_alt_text)
        # A moved focal point changes the crops; only those two small variants are decoded, by a signed-in editor.
        ProjectBannerVariantsJob.perform_now(@project)
        redirect_to @project
      else
        redirect_to @project, alert: "The banner focus couldn't be saved: #{@project.errors.full_messages.to_sentence}."
      end
    end
end
