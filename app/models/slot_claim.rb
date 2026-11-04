class SlotClaim < ApplicationRecord
  include RefreshesDashboard
  belongs_to :slot, counter_cache: :claims_count
  belongs_to :person
  # Through another record that a cascade delete may already have removed, so nil-safe.
  after_commit -> { slot&.project&.broadcast_refresh_later }

  validates :person_id, uniqueness: { scope: :slot_id }
end
