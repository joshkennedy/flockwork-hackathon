class Unavailability < ApplicationRecord
  belongs_to :organization

  NOTE_LIMIT = 200

  belongs_to :person

  validates :starts_on, :ends_on, presence: true
  validates :note, length: { maximum: NOTE_LIMIT }
  validate :ends_on_not_before_starts_on
  validate :person_belongs_to_organization

  scope :covering, ->(date) { where(starts_on: ..date, ends_on: date..) }
  scope :upcoming, ->(today = Date.current) { where(ends_on: today..).order(:starts_on, :id) }

  # What Leaders and Admins see: dates only, never the note.
  def away_label(today = Date.current)
    covers?(today) ? "Away until #{ends_on.strftime("%b %-d")}" : "Unavailable #{range_label}"
  end

  def covers?(date)
    starts_on <= date && ends_on >= date
  end

  def range_label
    today = Date.current
    starts = starts_on.strftime(starts_on.year == today.year ? "%b %-d" : "%b %-d, %Y")
    ends = if starts_on.month == ends_on.month && starts_on.year == ends_on.year
      ends_on.strftime("%-d")
    else
      ends_on.strftime(ends_on.year == today.year ? "%b %-d" : "%b %-d, %Y")
    end
    "#{starts} to #{ends}"
  end

  private
    def ends_on_not_before_starts_on
      return if starts_on.blank? || ends_on.blank? || ends_on >= starts_on

      errors.add(:ends_on, "must be on or after the start date")
    end

    def person_belongs_to_organization
      return if person&.organization_id == organization_id

      errors.add(:person, "must belong to the same Organization")
    end
end
