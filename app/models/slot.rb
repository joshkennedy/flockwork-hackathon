class Slot < ApplicationRecord
  belongs_to :project
  has_many :slot_claims, dependent: :destroy
  has_many :people, through: :slot_claims

  validates :date, presence: true
  validates :label, presence: true
  validates :capacity, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validate :capacity_is_not_below_current_claims

  scope :chronological, -> {
    order(:date, Arel.sql("starts_at_time ASC NULLS FIRST"), :starts_at_time, :id)
  }

  def self.grouped_by_date
    chronological.group_by(&:date)
  end

  def claim(person)
    claim = nil

    self.class.transaction do
      lock!

      if slot_claims.count >= capacity
        errors.add(:base, "This slot is full.")
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
    def capacity_is_not_below_current_claims
      return if capacity.blank?

      current_claims = slot_claims.count
      return if capacity >= current_claims

      errors.add(:capacity, "cannot be less than the current #{current_claims} claims")
    end
end
