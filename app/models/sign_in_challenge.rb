# A one-time sign-in code for someone who followed a Project's Public link. It hangs off the Organization and
# an address, not a Person, because the helper may not be a Person until the code proves the address is theirs.
class SignInChallenge < ApplicationRecord
  CHANNELS = %w[ email sms ].freeze
  LIFETIME = 15.minutes
  MAX_ATTEMPTS = 5
  # Each code costs an email or a text to an address nobody has confirmed yet.
  HOURLY_LIMIT = 5
  # Text pumping aims at premium international ranges, so for now only US and Canada (NANP) numbers get a text.
  TEXTABLE_PHONE = /\A\+1[2-9]\d{2}[2-9]\d{6}\z/
  # Far more than a church's helpers sign in by text in an hour, low enough that a pumping run stays cheap.
  ORGANIZATION_HOURLY_TEXT_LIMIT = 30

  belongs_to :organization
  belongs_to :project, optional: true
  # The Slot the helper tapped, kept here rather than in the session so the emailed link claims it on any device.
  belongs_to :slot, optional: true

  validates :channel, inclusion: { in: CHANNELS }
  validates :address, presence: true

  scope :unspent, -> { where(consumed_at: nil, expires_at: Time.current..) }
  scope :open, -> { unspent.where(attempts: ...MAX_ATTEMPTS) }

  # Returns the channel and the normalized address, or nil when the text is neither an email nor a phone.
  # shortcut: a bare 10-digit number is read as US or Canada (+1); other countries must type their country code.
  def self.parse(contact)
    value = contact.to_s.strip
    if value.include?("@")
      email = value.downcase
      [ "email", email ] if URI::MailTo::EMAIL_REGEXP.match?(email)
    else
      phone = value.gsub(/[\s().\-]/, "")
      phone = "1#{phone}" if /\A\d{10}\z/.match?(phone)
      phone = "+#{phone}" if /\A1\d{10}\z/.match?(phone)
      [ "sms", phone ] if /\A\+[1-9]\d{6,14}\z/.match?(phone)
    end
  end

  # A new challenge ends the earlier open ones for the address. Returns nil once the address has had its hour's share.
  # Used challenges stay as the hourly limits' record, and rows a day old are past every limit's window.
  # The Organization's row lock queues simultaneous requests, so the limits are counted one request at a time.
  def self.issue(organization:, project:, channel:, address:, slot: nil)
    organization.with_lock do
      earlier = where(organization:, address:)
      next if earlier.where(created_at: 1.hour.ago..).count >= HOURLY_LIMIT
      next if channel == "sms" && !textable?(organization, address)

      where(organization:, created_at: ...1.day.ago).delete_all
      earlier.open.update_all(expires_at: Time.current)
      create!(organization:, project:, slot:, channel:, address:, expires_at: LIFETIME.from_now)
    end
  end

  def self.textable?(organization, phone)
    TEXTABLE_PHONE.match?(phone) &&
      where(organization:, channel: "sms", created_at: 1.hour.ago..).count < ORGANIZATION_HOURLY_TEXT_LIMIT
  end

  def self.find_by_link_token(token)
    id, signature = token.to_s.split("-", 2)
    challenge = open.find_by(id: id) if /\A\d{1,18}\z/.match?(id)
    challenge if challenge && ActiveSupport::SecurityUtils.secure_compare(challenge.link_signature, signature.to_s)
  end

  def self.sign(data)
    OpenSSL::HMAC.digest("SHA256", Rails.application.key_generator.generate_key("sign_in_challenge"), data)
  end

  # Only the delivery job holds the plain code; the row keeps a keyed digest.
  def new_code!
    format("%06d", SecureRandom.random_number(1_000_000)).tap { |code| update!(code_digest: digest(code)) }
  end

  # Short enough for a text message. Signed over the current code, so it expires with the challenge and
  # stops working when a new code is issued.
  def link_token
    "#{id}-#{link_signature}"
  end

  def link_signature
    Base64.urlsafe_encode64(self.class.sign("link:#{id}:#{code_digest}"), padding: false).first(22)
  end

  def open?
    self.class.open.exists?(id:)
  end

  # Both updates are conditional, so the fifth wrong guess ends the challenge and two requests cannot share one code.
  def verify(code)
    self.class.open.where(id:).update_all("attempts = attempts + 1") == 1 &&
      ActiveSupport::SecurityUtils.secure_compare(code_digest.to_s, digest(code)) &&
      self.class.unspent.where(id:).update_all(consumed_at: Time.current) == 1
  end

  def consume
    self.class.open.where(id:).update_all(consumed_at: Time.current) == 1
  end

  # The address is proven, but a new helper has not given a name yet.
  def verified?
    consumed_at.present? && consumed_at > LIFETIME.ago && signed_in_at.nil?
  end

  # The row outlives the sign-in so the hourly limits still count it, but without a code it can never be used again.
  def mark_signed_in
    self.class.where(id:, signed_in_at: nil).update_all(signed_in_at: Time.current, code_digest: nil) == 1
  end

  # The name step, at most once. The Organization's lock, the one issue takes, makes a second submission wait and
  # then find the challenge used, or find the Person another challenge for the same address just made.
  # Returns nil when the challenge is no longer verified, and an unsaved Person when the name is not valid.
  def finish(name:)
    organization.with_lock do
      reload
      next unless verified?

      person = self.person || build_person(name:)
      mark_signed_in if person.persisted? || person.save
      person
    end
  end

  # Several People can share one phone, and nobody confirms a phone an Admin typed in. The match with the least
  # access wins (a non-Admin before an Admin, then the oldest), so a family phone never signs anyone in as an Admin
  # by accident. Most stored phones are as typed ("(202) 555-0123"), so the match is on digits, and a +1 number
  # also matches its ten-digit form, the same reading parse gives a bare ten-digit number.
  def person
    matching_people.active.order(:admin, :id).first
  end

  def removed_person?
    person.nil? && matching_people.where.not(removed_at: nil).exists?
  end

  def matching_people
    people = organization.people
    return people.where(email: address) if channel == "email"

    digits = address.delete("+")
    national = digits.delete_prefix("1") if digits.length == 11 && digits.start_with?("1")
    people.where("regexp_replace(phone, '\\D', '', 'g') IN (?)", [ digits, national ].compact)
  end

  # Nobody confirms a phone typed onto an Admin, so a wrong or recycled number must never hand over the Admin.
  def texts_an_admin?(person = self.person)
    channel == "sms" && person&.admin?
  end

  def build_person(name:)
    contact = channel == "email" ? { email: address } : { phone: address }
    organization.people.build(name:, joined_from_project: project, **contact)
  end

  def masked_address
    channel == "email" ? address.sub(/(?<=\A.).*(?=@)/, "•••") : "#{address.first(2)} ••• ••• #{address.last(4)}"
  end

  private
    def digest(code)
      Base64.urlsafe_encode64(self.class.sign("code:#{id}:#{code}"), padding: false)
    end
end
