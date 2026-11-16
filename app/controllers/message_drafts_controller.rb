class MessageDraftsController < ApplicationController
  before_action :set_project
  rate_limit to: 5, within: 10.minutes, by: -> { ai_rate_limit_key }, only: :create, with: -> {
    @purpose = params[:purpose].to_s
    @message = @project.messages.build
    @error = "Too many draft requests. Wait ten minutes, then try again."
    render :new, status: :too_many_requests
  }

  def new
    @purpose = "announcement"
    @message = @project.messages.build
  end

  def create
    @purpose = params[:purpose].to_s
    @message = @project.messages.build
    draft = ProjectMessageDraft.new(@project).call(@purpose)
    @message.body = "#{draft.title}\n\n#{draft.body}"
    render :new
  rescue ProjectMessageDraft::LimitReached => error
    @error = error.message
    render :new, status: :too_many_requests
  rescue ProjectMessageDraft::Unavailable => error
    @error = error.message
    render :new, status: :unprocessable_entity
  end

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
      raise ActiveRecord::RecordNotFound unless @project.enabled_tools.include?("messages") && Policy.can?(Current.person, :plan, @project)

      @open_spots_available = @project.active? && ProjectRisk.new(@project).open_spots.positive?
    end
end
