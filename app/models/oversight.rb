module Oversight
  module_function

  def serving_load(person)
    person.memberships.joins(:project).merge(Project.active).distinct.count(:project_id)
  end

  # Someone away on the date is not overextended; they appear under away_until instead.
  def overextended(organization, on: Date.current)
    organization.people
      .where.not(id: Unavailability.where(organization: organization).covering(on).select(:person_id))
      .joins(memberships: :project)
      .merge(Project.active)
      .select("people.*, COUNT(DISTINCT projects.id) AS serving_load")
      .group("people.id")
      .having("COUNT(DISTINCT projects.id) >= ?", organization.overextended_limit)
      .order(Arel.sql("COUNT(DISTINCT projects.id) DESC"), :name)
  end

  def away_until(organization, on: Date.current)
    Unavailability.where(organization: organization).covering(on).group(:person_id).maximum(:ends_on)
  end

  def upcoming_away(organization, today: Date.current, limit: 10)
    Unavailability.where(organization: organization).upcoming(today).includes(:person).limit(limit)
  end

  # Overextended people, minus anyone who checked in within the last CheckIn::RECENT_DAYS.
  def needs_check_in(organization, on: Date.current)
    recent = CheckIn.where(organization: organization).where(on: (on - CheckIn::RECENT_DAYS)..on).select(:person_id)
    overextended(organization, on: on).where.not(id: recent)
  end

  def never_asked(organization)
    organization.people.never_asked.order(:name)
  end

  def involvement(person)
    project_counts = counts_by_year(person.memberships, :created_at)
    task_counts = counts_by_year(person.completed_tasks, :completed_at)
    slot_counts = counts_by_year(person.slot_claims, :created_at)

    (project_counts.keys | task_counts.keys | slot_counts.keys).sort.reverse.map do |year|
      {
        year: year,
        projects: project_counts.fetch(year, 0),
        tasks: task_counts.fetch(year, 0),
        slots: slot_counts.fetch(year, 0)
      }
    end
  end

  def involvement_list(organization, year)
    people = organization.people.order(:name).to_a
    person_ids = people.map(&:id)
    period = Time.zone.local(year, 1, 1).all_year

    project_counts = organization.projects.joins(:memberships)
      .where(memberships: { person_id: person_ids, created_at: period })
      .group("memberships.person_id").count
    task_counts = organization.tasks.where(completed_by_id: person_ids, completed_at: period)
      .group(:completed_by_id).count
    slot_counts = organization.projects.joins(slots: :slot_claims)
      .where(slot_claims: { person_id: person_ids, created_at: period })
      .group("slot_claims.person_id").count

    people.map do |person|
      {
        person: person,
        projects: project_counts.fetch(person.id, 0),
        tasks: task_counts.fetch(person.id, 0),
        slots: slot_counts.fetch(person.id, 0)
      }
    end.sort_by do |entry|
      [ -(entry[:projects] + entry[:tasks] + entry[:slots]), entry[:person].name ]
    end
  end

  def counts_by_year(relation, column)
    attribute = relation.arel_table[column]
    relation.where(attribute.not_eq(nil)).group(attribute.extract("year")).count.transform_keys(&:to_i)
  end
  private_class_method :counts_by_year
end
