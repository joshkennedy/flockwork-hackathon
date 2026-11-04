class ProjectDuplicate
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :start_on, :date

  attr_reader :source, :by

  validates :name, :start_on, presence: true

  def initialize(source:, start_on:, by:)
    @source = source
    @by = by
    super(name: "#{source.name} (copy)", start_on:)
  end

  def call
    raise ActiveModel::ValidationError, self unless valid?

    Project.transaction do
      copy = create_project
      copy.memberships.create!(person: by, role: :leader)
      copy_tasks(copy)
      copied_schedule_items = copy_schedule_items(copy)
      copy_slots(copy, copied_schedule_items)
      copy_budget_lines(copy)
      copy_lists(copy)
      copy_debrief(copy)
      copy
    end
  end

  private
    def create_project
      source.organization.projects.create!(
        name:,
        description: source.description,
        starts_on: start_on,
        ends_on: shift(source.ends_on),
        owner: by,
        open_team: false,
        enabled_tools: source.enabled_tools,
        skills_needed: source.skills_needed
      )
    end

    def copy_debrief(copy)
      body = source.project_debrief&.notes_body
      return if body.blank?

      copy.notes.create!(organization: copy.organization, author: by, visibility: :leaders, body: body)
    end

    def copy_tasks(copy)
      source.tasks.find_each do |task|
        attributes = {
          title: task.title,
          due_on: shift(task.due_on),
          assignee: nil,
          completed_at: nil,
          completed_by: nil
        }
        attributes[:details] = task.details.body if task.details.body.present?
        copy.tasks.create!(attributes)
      end
    end

    def copy_schedule_items(copy)
      source.schedule_items.each_with_object({}) do |item, copied_items|
        copied_items[item.id] = copy.schedule_items.create!(
          date: shift(item.date),
          starts_at_time: item.starts_at_time,
          ends_at_time: item.ends_at_time,
          title: item.title,
          location: item.location
        )
      end
    end

    def copy_slots(copy, copied_schedule_items)
      source.slots.find_each do |slot|
        copy.slots.create!(
          date: shift(slot.date),
          starts_at_time: slot.starts_at_time,
          label: slot.label,
          capacity: slot.capacity,
          schedule_item: copied_schedule_items[slot.schedule_item_id]
        )
      end
    end

    def copy_budget_lines(copy)
      source.budget_lines.find_each do |line|
        copy.budget_lines.create!(
          kind: line.kind,
          description: line.description,
          estimated_cents: line.estimated_cents
        )
      end
    end

    def copy_lists(copy)
      source.lists.includes(:columns, :rows).order(:id).each do |source_list|
        copy_list = copy.lists.create!(name: source_list.name)
        copied_columns = copy_columns(source_list, copy_list)
        copy_rows(source_list, copy_list, copied_columns)
      end
    end

    def copy_columns(source_list, copy_list)
      source_list.columns.index_with do |column|
        copy_list.columns.create!(
          name: column.name,
          column_type: column.column_type,
          position: column.position
        )
      end
    end

    def copy_rows(source_list, copy_list, copied_columns)
      source_list.rows.each do |row|
        cells = source_list.columns.each_with_object({}) do |column, copied_cells|
          source_key = column.id.to_s
          next unless row.cells.key?(source_key)
          next if column.person?

          value = row.cells[source_key]
          value = shift(Date.iso8601(value.to_s)).iso8601 if column.date? && value.present?
          copied_cells[copied_columns.fetch(column).id.to_s] = value
        end

        copy_list.rows.create!(position: row.position, cells:)
      end
    end

    def shift(date)
      date&.+(offset)
    end

    def offset
      @offset ||= begin
        reference_date = source.starts_on || earliest_item_date
        reference_date ? (start_on - reference_date).to_i : 0
      end
    end

    def earliest_item_date
      [
        source.tasks.minimum(:due_on),
        source.schedule_items.minimum(:date),
        source.slots.minimum(:date),
        earliest_list_date
      ].compact.min
    end

    def earliest_list_date
      source.lists.includes(:columns, :rows).filter_map do |list|
        date_columns = list.columns.select(&:date?)
        list.rows.flat_map do |row|
          date_columns.filter_map do |column|
            value = row.cells[column.id.to_s]
            Date.iso8601(value.to_s) if value.present?
          end
        end.min
      end.min
    end
end
