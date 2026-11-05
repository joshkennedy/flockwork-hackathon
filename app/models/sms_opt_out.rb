# A phone that replied STOP to Sendly. disabled_preferences maps person id => the SMS kinds
# the opt-out turned off, so START restores only those.
class SmsOptOut < ApplicationRecord
  def self.blocked?(phone)
    exists?(phone: normalize(phone))
  end

  def self.normalize(phone)
    Person.normalize_value_for(:phone, phone.to_s)
  end

  def self.opt_out!(phone)
    phone = normalize(phone)
    transaction do
      record = find_or_create_by!(phone:) { |opt_out| opt_out.opted_out_at = Time.current }
      Person.where(phone:).find_each do |person|
        kinds = Notification::KINDS.keys.select { |kind| person.notification_for?("sms", kind) }
        next if kinds.empty?

        record.disabled_preferences[person.id.to_s] = (record.disabled_preferences[person.id.to_s].to_a | kinds)
        person.update_columns(sms_preferences: person.sms_preferences.merge(kinds.index_with { false }))
      end
      record.save!
    end
  end

  def self.opt_in!(phone)
    transaction do
      record = find_by(phone: normalize(phone))
      next unless record

      record.disabled_preferences.each do |person_id, kinds|
        # A Person who changed numbers after STOP never consented to SMS on the new one.
        person = Person.find_by(id: person_id, phone: record.phone)
        person&.update_columns(sms_preferences: person.sms_preferences.merge(kinds.index_with { true }))
      end
      record.destroy!
    end
  end
end
