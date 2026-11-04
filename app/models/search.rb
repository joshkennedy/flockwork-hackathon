class Search
  LIMIT = 8
  WORK = {
    "Tasks" => [ Task, "title", "tasks" ],
    "Slots" => [ Slot, "label", "signup_sheet" ],
    "Schedule" => [ ScheduleItem, "title", "schedule" ],
    "Docs & Files" => [ DocItem, "title", "docs" ]
  }.freeze

  def initialize(person, query)
    @person, @query = person, query
  end

  def results
    return {} if @query.blank?

    ApplicationRecord.transaction do
      ApplicationRecord.connection.execute("SET LOCAL pg_trgm.word_similarity_threshold = 0.4")
      projects = Policy.visible_projects(@person)
      groups = { "Projects" => matching(Project.where(id: projects.select(:id)), "name") }
      if Policy.can?(@person, :view_oversight, Current.organization)
        groups["People"] = matching(Current.organization.people, "name")
      end
      WORK.each do |label, (model, column, tool)|
        enabled = projects.where("? = ANY(projects.enabled_tools)", tool)
        groups[label] = matching(model.where(project_id: enabled.select(:id)), column).includes(:project)
      end
      groups.transform_values(&:to_a)
    end
  end

  private
    def matching(scope, column)
      field = "#{scope.table_name}.#{column}"
      words = @query.split.first(8)
      words.each do |word|
        pattern = "%#{ApplicationRecord.sanitize_sql_like(word)}%"
        scope = if word.length >= 3
          scope.where("#{field} ILIKE :pattern OR #{field} %> :word", pattern: pattern, word: word)
        else
          scope.where("#{field} ILIKE ?", pattern)
        end
      end
      rank = ApplicationRecord.sanitize_sql_array([ "word_similarity(?, #{field}) DESC, #{field} ASC", @query ])
      scope.order(Arel.sql(rank)).order(:id).limit(LIMIT)
    end
end
