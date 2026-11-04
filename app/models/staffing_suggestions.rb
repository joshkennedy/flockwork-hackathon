# People a Leader might invite to a Project, ranked in Ruby from the directory. No AI sees any of this (ADR 0002).
# Someone is suggested when they list at least one of the Project's skills_needed and nothing rules them out:
# already on or asked to the Team, a Recipient of it, unable to sign in, away during it, or overextended.
class StaffingSuggestions
  Suggestion = Data.define(:person, :matched_skills, :serving_load)

  LIMIT = 5

  def initialize(project)
    @project = project
  end

  def call
    return [] if needed.empty?

    candidates.map { |person| Suggestion.new(person:, matched_skills: person.skills & needed, serving_load: person.serving_load.to_i) }
      .sort_by { |suggestion| [ -suggestion.matched_skills.size, suggestion.serving_load, suggestion.person.name ] }
      .first(LIMIT)
  end

  private
    attr_reader :project

    def needed = project.skills_needed

    def organization = project.organization

    def candidates
      people = organization.people
        .where("people.skills && ARRAY[?]::varchar[]", needed)
        .where.not(email: [ nil, "" ])
        .where.not(id: project.memberships.select(:person_id))
        .where.not(id: project.invitations.select(:person_id))
        .where.not(id: project.recipients.select(:person_id))
        .left_joins(memberships: :project)
        .select("people.*, COUNT(DISTINCT projects.id) FILTER (WHERE #{active_sql}) AS serving_load")
        .group("people.id")
        .having("COUNT(DISTINCT projects.id) FILTER (WHERE #{active_sql}) < ?", organization.overextended_limit)
      away = away_during_project
      away ? people.where.not(id: away) : people
    end

    def active_sql = "projects.done_at IS NULL AND projects.archived_at IS NULL AND projects.deleted_at IS NULL"

    # Overlap with the Project's dates; with either date unknown, being away cannot rule anyone out.
    def away_during_project
      return unless project.starts_on && project.ends_on

      Unavailability.where(organization:).where(starts_on: ..project.ends_on, ends_on: project.starts_on..).select(:person_id)
    end
end
