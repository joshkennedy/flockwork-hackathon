require "did_you_mean/levenshtein"

module SearchHelper
  def search_pages(query)
    organization_navigation.select do |label, _path, _icon|
      query.split.all? do |token|
        label.downcase.include?(token.downcase) || (token.length >= 3 && label.split.any? { |word| DidYouMean::Levenshtein.distance(word.downcase, token.downcase) <= 1 })
      end
    end
  end

  def search_highlight(text, query)
    tokens = query.to_s.split.first(8)
    matches = text.scan(/[[:alnum:]]+/).select do |word|
      tokens.any? do |token|
        token.length >= 3 && DidYouMean::Levenshtein.distance(word.downcase, token.downcase) <= (token.length >= 6 ? 2 : 1)
      end
    end
    highlight(text, (tokens + matches).uniq, highlighter: '<mark class="search-match">\1</mark>')
  end

  def search_result(record)
    case record
    when Project then [ record.name, "Project", project_path(record) ]
    when Person then [ record.name, "Person", Current.person.admin? ? person_path(record) : search_person_path(record) ]
    when Task then [ record.title, record.project.name, project_path(record.project, anchor: "tab-tasks") ]
    when Slot then [ record.label, "#{record.project.name} · #{record.date.strftime('%b %-d, %Y')}", project_path(record.project, anchor: "tab-signup_sheet") ]
    when ScheduleItem then [ record.title, "#{record.project.name} · #{record.date.strftime('%b %-d, %Y')}", project_path(record.project, anchor: "tab-schedule") ]
    when DocItem then [ record.title, record.project.name, project_path(record.project, anchor: "tab-docs") ]
    end
  end
end
