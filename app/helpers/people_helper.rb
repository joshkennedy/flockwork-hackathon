module PeopleHelper
  def skill_list(skills)
    skills.map { |skill| Skills.label(skill) }.join(", ")
  end

  # Status chips are 4px badges. DESIGN.md keeps pill shapes to the Person pill, so a chip never becomes one.
  def person_chips(person, leader: false, away_until: nil, never_asked: false)
    chips = []
    chips << tag.span("Leader", class: "status-chip") if leader
    chips << tag.span("Admin", class: "status-chip") if person.admin?
    chips << tag.span("Away until #{short_date(away_until)}", class: "status-chip") if away_until
    chips << tag.span("Not yet asked", class: "status-chip status-chip-need") if never_asked
    chips << tag.span("Joined from a public link", class: "status-chip") if person.joined_from_project_id?
    chips << tag.span("Can't sign in", class: "status-chip") unless person.can_sign_in?
    tag.span(safe_join(chips), class: "inline-flex min-w-0 flex-wrap items-center gap-1.5")
  end

  def short_date(date)
    date.year == Date.current.year ? date.strftime("%b %-d") : date.strftime("%b %-d, %Y")
  end

  # Names the Active Projects a Person serves on, two at most, so a directory row stays one line.
  # Nil when they serve on none: the row shows just the name, and the Serving now filter covers the rest.
  def serving_line(names)
    return if names.empty?

    shown = names.first(2).to_sentence
    names.size > 2 ? "Serving on #{shown}, and #{names.size - 2} more" : "Serving on #{shown}"
  end
end
