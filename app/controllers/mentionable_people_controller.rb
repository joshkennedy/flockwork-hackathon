class MentionablePeopleController < ApplicationController
  def index
    project = Policy.visible_projects(Current.person).find(params[:id])
    query = ActiveRecord::Base.sanitize_sql_like(params[:q].to_s)
    people = Current.workspace.people
      .where("name ILIKE ?", "%#{query}%")
      .order(:name)
      .select { |person| Policy.can?(person, :show, project) }

    render json: { people: people.map { |person| { id: person.id, name: person.name } } }
  end
end
