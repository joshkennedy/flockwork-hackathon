class CheckIn < ApplicationRecord
  belongs_to :organization

  # A check-in this recent takes the person out of the "may need a check-in" list.
  RECENT_DAYS = 30
  NOTE_LIMIT = 280

  belongs_to :person
  belongs_to :checked_in_by, class_name: "Person", optional: true, inverse_of: :logged_check_ins

  validates :on, presence: true
  validates :note, length: { maximum: NOTE_LIMIT }
  validate :on_not_in_the_future
  validate :people_belong_to_organization

  scope :latest_first, -> { order(on: :desc, id: :desc) }

  def self.latest_by_person(person_ids)
    where(person_id: person_ids).includes(:checked_in_by).latest_first.group_by(&:person_id).transform_values(&:first)
  end

  private
    def on_not_in_the_future
      return if on.blank? || on <= Date.current

      errors.add(:on, "cannot be in the future")
    end

    def people_belong_to_organization
      errors.add(:person, "must belong to the same church") unless person&.organization_id == organization_id
      errors.add(:checked_in_by, "must belong to the same church") unless checked_in_by.nil? || checked_in_by.organization_id == organization_id
    end
end
