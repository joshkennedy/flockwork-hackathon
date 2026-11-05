class ProjectBannersController < ApplicationController
  before_action :set_project
  before_action :authorize_banner

  def update
    upload = params.dig(:project, :banner)
    if upload.present?
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
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def authorize_banner
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :update, @project)
    end

    def replace_banner(upload)
      @project.banner = upload
      @project.reset_banner_focus
      if @project.save
        @project.banner.blob.analyze
        if (message = @project.reject_banner_for_pixel_limits!)
          redirect_to @project, alert: "The banner couldn't be saved: Banner #{message}."
          return
        end
        ProjectBannerFocusJob.perform_later(@project, @project.banner.blob_id)
        redirect_to @project
      else
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
        redirect_to @project
      else
        redirect_to @project, alert: "The banner focus couldn't be saved: #{@project.errors.full_messages.to_sentence}."
      end
    end
end
