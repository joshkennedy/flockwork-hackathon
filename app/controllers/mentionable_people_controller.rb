class MentionablePeopleController < ApplicationController
  def index
    project = Policy.visible_projects(Current.person).find(params[:id])
    raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :comment, project)

    query = ActiveRecord::Base.sanitize_sql_like(params[:q].to_s)
    people = Current.organization.people.where(id: project.memberships.select(:person_id))
      .or(Current.organization.people.where(admin: true))
      .where("name ILIKE ?", "%#{query}%")
      .order(:name)
      .select { |person| Policy.can?(person, :show, project) }

    render json: { people: people.map { |person|
      { id: person.id, name: person.name, initials: helpers.person_initials(person.name), hue: helpers.avatar_hue(person),
        sgid: person.attachable_sgid, content: helpers.person_pill(person) }
    } }
  end
end
