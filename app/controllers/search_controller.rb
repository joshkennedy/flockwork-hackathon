class SearchController < ApplicationController
  LIMIT = 8

  def person
    raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :view_oversight, Current.organization)

    @person = Current.organization.people.find(params[:id])
    @projects = Policy.visible_projects(Current.person).where(id: @person.memberships.select(:project_id)).order(:name, :id)
  end

  def index
    @results_frame = request.headers["Turbo-Frame"] == "search-results" ? "search-results" : "search-page-results"
    @query = params[:query].to_s.strip.first(100)
    @project = Policy.visible_projects(Current.person).find(params[:project_id]) if params[:project_id].present?
    @results = {}
    return if @query.blank?

    pattern = "%#{Project.sanitize_sql_like(@query)}%"
    @results["Projects"] = Policy.visible_projects(Current.person).where("projects.name ILIKE ?", pattern).order(:name, :id).limit(LIMIT)
    if Policy.can?(Current.person, :view_oversight, Current.organization)
      @results["People"] = Current.organization.people.matching(@query).order(:name, :id).limit(LIMIT)
    end
    return unless @project

    @results["Tasks"] = @project.tasks.where("title ILIKE ?", pattern).order(:title, :id).limit(LIMIT) if @project.enabled_tools.include?("tasks")
    @results["Slots"] = @project.slots.where("label ILIKE ?", pattern).order(:date, :id).limit(LIMIT) if @project.enabled_tools.include?("signup_sheet")
  end
end
