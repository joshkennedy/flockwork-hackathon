# A one-time sign-in code for someone who followed a Project's Public link. It hangs off the Organization and
# an address, not a Person, because the helper may not be a Person until the code proves the address is theirs.
class SignInChallenge < ApplicationRecord
  CHANNELS = %w[ email sms ].freeze
  LIFETIME = 15.minutes
  MAX_ATTEMPTS = 5
  # Each code costs an email or a text to an address nobody has confirmed yet.
  HOURLY_LIMIT = 5

  belongs_to :organization
  belongs_to :project, optional: true

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
  def self.issue(organization:, project:, channel:, address:)
    earlier = where(organization:, address:)
    return if earlier.where(created_at: 1.hour.ago..).count >= HOURLY_LIMIT

    transaction do
      earlier.where(created_at: ...1.day.ago).delete_all
      earlier.open.update_all(expires_at: Time.current)
      create!(organization:, project:, channel:, address:, expires_at: LIFETIME.from_now)
    end
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
    consumed_at.present? && consumed_at > LIFETIME.ago
  end

  # Several People can share one phone, and nobody confirms a phone an Admin typed in. The match with the least
  # access wins (a non-Admin before an Admin, then the oldest), so a family phone never signs anyone in as an Admin
  # by accident. Stored phones without a country code never match, because the verified address is always E.164.
  def person
    people = organization.people
    channel == "email" ? people.find_by(email: address) : people.where(phone: address).order(:admin, :id).first
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
