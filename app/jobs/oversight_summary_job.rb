class OversightSummaryJob < ApplicationJob
  queue_as :default

  # Keep already queued jobs executable after AI summary generation is removed.
  def perform(key, _facts)
    Rails.cache.delete("#{key}/pending")
  end
end
