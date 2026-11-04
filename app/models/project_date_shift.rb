class ProjectDateShift
  LIMIT = 365

  def self.days(value)
    text = value.to_s
    raise ArgumentError, "Shift must be whole days within a year" unless text.match?(/\A-?\d+\z/)

    count = Integer(text, 10)
    raise ArgumentError, "Shift must be nonzero whole days within a year" unless count.between?(-LIMIT, LIMIT) && count.nonzero?

    count
  end

  def initialize(project, days:)
    @project = project
    @days = self.class.days(days)
  end

  def call
    @project.with_lock do
      @project.update!(starts_on: shift(@project.starts_on), ends_on: shift(@project.ends_on))
      @project.tasks.find_each { |task| task.update!(due_on: shift(task.due_on)) }
      @project.schedule_items.find_each { |item| item.update!(date: shift(item.date)) }
      @project.slots.find_each { |slot| slot.update!(date: shift(slot.date)) }
      @project.lists.includes(:columns, :rows).each do |list|
        columns = list.columns.select(&:date?)
        list.rows.each do |row|
          cells = row.cells.deep_dup
          columns.each do |column|
            key = column.id.to_s
            cells[key] = shift(Date.iso8601(cells[key])).iso8601 if cells[key].present?
          end
          row.update!(cells:) if cells != row.cells
        end
      end
    end
    @project
  end

  private
    def shift(date) = date && date + @days
end
