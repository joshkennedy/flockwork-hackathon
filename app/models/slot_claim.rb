class SlotClaim < ApplicationRecord
  belongs_to :slot, counter_cache: :claims_count
  belongs_to :person

  validates :person_id, uniqueness: { scope: :slot_id }
end
