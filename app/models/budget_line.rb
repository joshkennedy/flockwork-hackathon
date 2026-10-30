class BudgetLine < ApplicationRecord
  belongs_to :project
  belongs_to :responsible_person, class_name: "Person", optional: true

  enum :kind, { booking: 0, purchase: 1 }
  enum :status, { pending: 0, reserved: 1, paid: 2, cancelled: 3 }, default: :pending

  validates :description, presence: true
  validates :estimated_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :actual_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :responsible_person_is_team_member

  def estimated=(dollar_string)
    @estimated_input = dollar_string
    self.estimated_cents = self.class.cents_from_dollars(dollar_string)
  end

  def estimated
    @estimated_input.presence || self.class.format_cents(estimated_cents)
  end

  def actual=(dollar_string)
    @actual_input = dollar_string
    self.actual_cents = dollar_string.blank? ? nil : self.class.cents_from_dollars(dollar_string)
  end

  def actual
    return @actual_input if @actual_input.present?
    return "" if actual_cents.nil?

    self.class.format_cents(actual_cents)
  end

  def actual_cents_for_total
    actual_cents || 0
  end

  def self.cents_from_dollars(dollar_string)
    return nil if dollar_string.blank?

    (BigDecimal(dollar_string.to_s.delete(",")) * 100).round(0).to_i
  end

  def self.format_cents(cents)
    return "" if cents.nil?

    dollars, fraction = cents.abs.divmod(100)
    formatted_dollars = dollars.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    sign = cents.negative? ? "-" : ""
    "#{sign}$#{formatted_dollars}.#{fraction.to_s.rjust(2, "0")}"
  end

  def self.estimated_total_cents(lines)
    lines.sum(&:estimated_cents)
  end

  def self.actual_total_cents(lines)
    lines.sum(&:actual_cents_for_total)
  end

  private
    def responsible_person_is_team_member
      return if responsible_person_id.blank?

      unless project.memberships.exists?(person_id: responsible_person_id)
        errors.add(:responsible_person, "must be on the Team")
      end
    end
end
