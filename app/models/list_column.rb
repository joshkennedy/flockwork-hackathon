class ListColumn < ApplicationRecord
  class CastError < StandardError; end

  belongs_to :list
  # Through another record that a cascade delete may already have removed, so nil-safe.
  after_commit -> { list&.project&.broadcast_refresh_later }

  enum :column_type, { text: 0, number: 1, date: 2, checkbox: 3, person: 4 }, validate: true

  validates :name, presence: true
  validates :position, presence: true
  validate :type_change_does_not_discard_values, on: :update

  before_validation :assign_position, on: :create

  def cast(raw)
    return ActiveModel::Type::Boolean.new.cast(raw) if checkbox?
    return if raw.blank?

    case column_type
    when "text"
      raw.to_s
    when "number"
      cast_number(raw)
    when "date"
      Date.iso8601(raw.to_s).iso8601
    when "person"
      cast_person(raw)
    end
  rescue ArgumentError
    raise CastError, "#{name} is not a valid #{column_type}"
  end

  def display(value)
    return if value.nil? || value == ""

    case column_type
    when "date"
      Date.iso8601(value.to_s).to_fs(:long)
    when "checkbox"
      value ? "Yes" : "No"
    when "person"
      list.project.people.find_by(id: value)&.name
    else
      value.to_s
    end
  rescue ArgumentError
    value.to_s
  end

  def move_up!
    neighbor = list.columns.where("position < ?", position).reorder(position: :desc, id: :desc).first
    swap_position_with!(neighbor)
  end

  def move_down!
    neighbor = list.columns.where("position > ?", position).reorder(:position, :id).first
    swap_position_with!(neighbor)
  end

  private
    def assign_position
      self.position ||= (list.columns.maximum(:position) || 0) + 1
    end

    def cast_number(raw)
      number = BigDecimal(raw.to_s, exception: false)
      raise CastError, "#{name} is not a valid number" unless number&.finite?

      number.frac.zero? ? number.to_i : number.to_f
    end

    def cast_person(raw)
      person_id = Integer(raw, exception: false)
      unless person_id && list.project.memberships.exists?(person_id: person_id)
        raise CastError, "#{name} must be a Team member of this Project"
      end

      person_id
    end

    def type_change_does_not_discard_values
      return unless will_save_change_to_column_type?
      return unless list.rows.pluck(:cells).any? { |cells| cells[id.to_s].present? }

      errors.add(:base, "Delete the values in this column first, then change its type.")
    end

    def swap_position_with!(neighbor)
      return unless neighbor

      original_position = position
      transaction do
        update!(position: neighbor.position)
        neighbor.update!(position: original_position)
      end
    end
end
