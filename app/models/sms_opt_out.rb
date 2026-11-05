# One row per phone that has sent STOP or START to Sendly. disabled_preferences maps person id => the
# SMS kinds the opt-out turned off, so START restores only those. last_event_at orders events,
# because Sendly retries deliveries and a late START must not undo a newer STOP.
class SmsOptOut < ApplicationRecord
  def self.blocked?(phone)
    exists?(phone: normalize(phone), opted_out: true)
  end

  def self.normalize(phone)
    Person.normalize_value_for(:phone, phone.to_s)
  end

  def self.opt_out!(phone, at:)
    transition(phone, at) do |record|
      record.opted_out = true
      record.opted_out_at = at
      Person.where(phone: record.phone).find_each do |person|
        kinds = Notification::KINDS.keys.select { |kind| person.notification_for?("sms", kind) }
        next if kinds.empty?

        record.disabled_preferences[person.id.to_s] = record.disabled_preferences[person.id.to_s].to_a | kinds
        person.update_columns(sms_preferences: person.sms_preferences.merge(kinds.index_with { false }))
      end
    end
  end

  def self.opt_in!(phone, at:)
    transition(phone, at) do |record|
      record.disabled_preferences.each do |person_id, kinds|
        # A Person who changed numbers after STOP never consented to SMS on the new one.
        person = Person.find_by(id: person_id, phone: record.phone)
        person&.update_columns(sms_preferences: person.sms_preferences.merge(kinds.index_with { true }))
      end
      record.opted_out = false
      record.disabled_preferences = {}
    end
  end

  # The advisory lock serializes transitions per phone even before its row exists.
  def self.transition(phone, at)
    phone = normalize(phone)
    transaction do
      connection.execute("SELECT pg_advisory_xact_lock(#{sanitize_sql_array([ "hashtext(?)", phone ])})")
      record = find_or_initialize_by(phone:)
      next if record.persisted? && at <= record.last_event_at

      yield record
      record.last_event_at = at
      record.opted_out_at ||= at
      record.save!
    end
  end
  private_class_method :transition
end
