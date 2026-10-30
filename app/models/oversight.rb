module Oversight
  module_function

  def serving_load(person)
    person.memberships.joins(:project).merge(Project.active).distinct.count(:project_id)
  end

  def overextended(workspace)
    workspace.people
      .joins(memberships: :project)
      .merge(Project.active)
      .select("people.*, COUNT(DISTINCT projects.id) AS serving_load")
      .group("people.id")
      .having("COUNT(DISTINCT projects.id) >= ?", workspace.overextended_limit)
      .order(Arel.sql("COUNT(DISTINCT projects.id) DESC"), :name)
  end

  def never_asked(workspace)
    # Invitations and ownership preserve Team history after Membership deletion; soft-deleted Projects retain Memberships.
    workspace.people.where.missing(:invitations, :memberships, :owned_projects).order(:name)
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

  def involvement_list(workspace, year)
    people = workspace.people.order(:name).to_a
    person_ids = people.map(&:id)
    period = Time.zone.local(year, 1, 1).all_year

    project_counts = workspace.projects.joins(:memberships)
      .where(memberships: { person_id: person_ids, created_at: period })
      .group("memberships.person_id").count
    task_counts = workspace.tasks.where(completed_by_id: person_ids, completed_at: period)
      .group(:completed_by_id).count
    slot_counts = workspace.projects.joins(slots: :slot_claims)
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
