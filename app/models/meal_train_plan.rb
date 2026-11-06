class MealTrainPlan
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string, default: "Meal train"
  attribute :label, :string, default: "Dinner"
  attribute :start_date, :string
  attribute :days, :string, default: "14"
  attribute :every, :string, default: "1"
  attribute :time, :string
  attribute :capacity, :string, default: "1"

  validates :name, length: { maximum: 200 }
  validates :name, presence: true, on: :complete
  validates :label, length: { maximum: 200 }
  validates :label, :start_date, presence: true, on: [ :complete, :schedule ]
  validates :days, numericality: { only_integer: true, in: 1..60 }
  validates :every, inclusion: { in: %w[1 2] }
  validates :capacity, numericality: { only_integer: true, in: 1..100 }
  validate :valid_date_and_time

  def complete?
    valid?(:complete)
  end

  def candidates(series_key: "meal-slots")
    return [] unless valid?(:schedule)

    (0...days.to_i).step(every.to_i).map do |offset|
      Planner::PendingItems.candidate(
        source_key: "#{series_key}:#{offset}",
        fields: { "label" => label.strip, "date" => (Date.iso8601(start_date) + offset).iso8601,
                  "time" => time.presence, "capacity" => capacity.to_i },
        metadata: { "day_offset" => offset }
      )
    end
  end

  def self.from_session(session)
    return new(session.meal_setup) if session.meal_setup.present?

    items = session.pending_items
    first = items.first
    fields = first&.fetch("suggested_fields", nil) || first&.fetch("fields", {}) || {}
    dates = items.filter_map { |item| Date.iso8601((item["suggested_fields"] || item["fields"])["date"]) rescue nil }
    offsets = items.filter_map { |item| item["day_offset"] }
    duration = dates.any? ? (dates.max - dates.min).to_i + 1 : offsets.max&.+(1)
    new(name: session.project.name, label: fields["label"].presence || "Dinner",
      start_date: dates.min&.iso8601 || session.project.starts_on&.iso8601,
      days: duration || 14, time: fields["time"], capacity: fields["capacity"] || 1)
  end

  private
    def valid_date_and_time
      if start_date.present?
        begin
          Date.iso8601(start_date)
        rescue Date::Error
          errors.add(:start_date, "must be a valid date")
        end
      end
      errors.add(:time, "must be a valid delivery time") if time.present? && !time.match?(Planner::FieldValidation::TIME)
    end
end
