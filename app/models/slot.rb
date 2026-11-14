class Slot < ApplicationRecord
  include RefreshesDashboard
  belongs_to :project
  belongs_to :schedule_item, optional: true
  broadcasts_refreshes_to :project
  has_many :slot_claims, dependent: :destroy
  has_many :people, through: :slot_claims
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :follows, as: :followable, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy

  validates :date, presence: true
  validates :label, presence: true
  validates :capacity, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validate :schedule_item_belongs_to_project
  validate :capacity_is_not_below_current_claims
  before_validation :follow_schedule_item_date

  scope :chronological, -> {
    order(:date, Arel.sql("starts_at_time ASC NULLS FIRST"), :starts_at_time, :id)
  }

  scope :this_week, -> { where(date: Date.current..(Date.current + 6)) }
  scope :with_open_spots, -> { where("claims_count < capacity") }

  def self.open_this_week_by_project(project_ids)
    where(project_id: project_ids).this_week.with_open_spots.includes(:project).chronological.group_by(&:project)
  end

  def claim(person)
    claim = nil

    self.class.transaction do
      lock!

      if date < Date.current
        errors.add(:base, "This Slot has passed.")
      elsif slot_claims.count >= capacity
        errors.add(:base, "This Slot is full. Pick another one.")
      else
        claim = slot_claims.create(person:)
      end
    end

    claim
  end

  def full?
    claims_count >= capacity
  end

  private
    def follow_schedule_item_date
      self.date = schedule_item.date if schedule_item
    end

    def schedule_item_belongs_to_project
      return if schedule_item.nil? || schedule_item.project_id == project_id

      errors.add(:schedule_item, "must belong to the same Project")
    end

    def capacity_is_not_below_current_claims
      return if capacity.blank?

      current_claims = slot_claims.count
      return if capacity >= current_claims

      errors.add(:capacity, "can't go below #{current_claims} #{"person".pluralize(current_claims)} already signed up")
    end
end
