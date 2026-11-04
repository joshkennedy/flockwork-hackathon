class ListRow < ApplicationRecord
  belongs_to :list
  # Through another record that a cascade delete may already have removed, so nil-safe.
  after_commit -> { list&.project&.broadcast_refresh_later }
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :follows, as: :followable, dependent: :destroy

  validates :position, presence: true

  before_validation :assign_position, on: :create

  delegate :project, to: :list

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
