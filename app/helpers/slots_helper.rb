module SlotsHelper
  def self.count_noun(slots)
    labels = slots.map { |slot| slot.label.downcase }.uniq
    labels.one? && slots.all? { |slot| slot.capacity == 1 } ? labels.first : "spot"
  end
end
