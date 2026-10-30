class ProjectDuplicatesController < ApplicationController
  before_action :set_source
  before_action :authorize_duplicate

  def new
    @project_duplicate = build_project_duplicate(start_on: @source.starts_on&.next_year)
  end

  def create
    @project_duplicate = build_project_duplicate(start_on: nil)
    @project_duplicate.assign_attributes(project_duplicate_params)

    if @project_duplicate.valid?
      copy = @project_duplicate.call
      redirect_to copy
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def set_source
      @source = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def authorize_duplicate
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :duplicate, @source)
    end

    def build_project_duplicate(start_on:)
      ProjectDuplicate.new(source: @source, start_on:, by: Current.person)
    end

    def project_duplicate_params
      params.expect(project_duplicate: [ :name, :start_on ])
    end
end
