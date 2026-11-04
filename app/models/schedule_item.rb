class ScheduleItem < ApplicationRecord
  belongs_to :project
  broadcasts_refreshes_to :project
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :follows, as: :followable, dependent: :destroy

  validates :date, presence: true
  validates :title, presence: true
  validate :ends_at_time_is_not_before_starts_at_time

  scope :chronological, -> {
    order(:date, Arel.sql("starts_at_time ASC NULLS FIRST"), :starts_at_time, :id)
  }

  def self.grouped_by_day
    chronological.group_by(&:date)
  end

  private
    def ends_at_time_is_not_before_starts_at_time
      return if starts_at_time.blank? || ends_at_time.blank?
      return if ends_at_time >= starts_at_time

      errors.add(:ends_at_time, "must be at or after the start time")
    end
end
