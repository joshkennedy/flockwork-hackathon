class ScheduleItem < ApplicationRecord
  belongs_to :project
  broadcasts_refreshes_to :project
  has_many :slots, dependent: :nullify
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :follows, as: :followable, dependent: :destroy

  validates :date, presence: true
  validates :title, presence: true
  validate :ends_at_time_is_not_before_starts_at_time
  after_update :update_linked_slot_dates, if: :saved_change_to_date?

  scope :chronological, -> {
    order(:date, Arel.sql("starts_at_time ASC NULLS FIRST"), :starts_at_time, :id)
  }

  def self.grouped_by_day
    chronological.group_by(&:date)
  end

  private
    def update_linked_slot_dates
      slots.update_all(date:, updated_at: Time.current)
    end

    def ends_at_time_is_not_before_starts_at_time
      return if starts_at_time.blank? || ends_at_time.blank?
      return if ends_at_time >= starts_at_time

      errors.add(:ends_at_time, "must be at or after the start time")
    end
end
