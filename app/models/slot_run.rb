class SlotRun
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :start_date, :date
  attribute :end_date, :date
  attribute :starts_at_time, :time
  attribute :label, :string
  attribute :capacity, :integer, default: 1
  attribute :claim_prompt, :string

  validates :start_date, :end_date, :label, presence: true
  validates :capacity, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :claim_prompt, length: { maximum: 120 }, allow_blank: true
  validate :end_date_is_not_before_start_date
  validate :date_range_is_not_more_than_sixty_days

  def initialize(project:, **attributes)
    @project = project
    super(attributes)
  end

  def save
    return false unless valid?

    @project.transaction do
      (start_date..end_date).each do |date|
        @project.slots.create!(date:, starts_at_time:, label:, capacity:, claim_prompt:)
      end
    end

    true
  end

  private
    def end_date_is_not_before_start_date
      return if start_date.blank? || end_date.blank? || end_date >= start_date

      errors.add(:end_date, "must be on or after the start date")
    end

    def date_range_is_not_more_than_sixty_days
      return if start_date.blank? || end_date.blank? || end_date < start_date
      return if (end_date - start_date).to_i < 60

      errors.add(:end_date, "must be within 60 days of the start date")
    end
end
