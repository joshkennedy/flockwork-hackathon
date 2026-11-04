class SearchController < ApplicationController
  def person
    raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :view_oversight, Current.organization)

    @person = Current.organization.people.find(params[:id])
    @projects = Policy.visible_projects(Current.person).where(id: @person.memberships.select(:project_id)).order(:name, :id)
  end

  def index
    @results_frame = request.headers["Turbo-Frame"] == "search-results" ? "search-results" : "search-page-results"
    @query = params[:query].to_s.strip.first(100)
    @project = Policy.visible_projects(Current.person).find(params[:project_id]) if params[:project_id].present?
    @results = Search.new(Current.person, @query).results
    render partial: "search/results", locals: { results_frame: @results_frame, query: @query, results: @results } if request.headers["Turbo-Frame"].present?
  end
end
