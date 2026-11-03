class OversightSummaryJob < ApplicationJob
  queue_as :default

  def perform(key, facts)
    sentence = OversightSummary.generate(facts)
    Rails.cache.write(key, sentence || OversightSummary::FAILED, expires_in: sentence ? OversightSummary::TTL : 1.hour)
  ensure
    Rails.cache.delete("#{key}/pending")
  end
end
