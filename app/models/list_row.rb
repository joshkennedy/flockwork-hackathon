class ListRow < ApplicationRecord
  belongs_to :list

  validates :position, presence: true

  before_validation :assign_position, on: :create

  def assign_cast_cells(raw_cells)
    values = cells.dup

    list.columns.each do |column|
      key = column.id.to_s
      next unless raw_cells.key?(key)

      value = column.cast(raw_cells[key])
      value.nil? ? values.delete(key) : values[key] = value
    rescue ListColumn::CastError => error
      errors.add(:base, error.message)
    end

    self.cells = values
    errors.empty?
  end

  private
    def assign_position
      self.position ||= (list.rows.maximum(:position) || 0) + 1
    end
end
