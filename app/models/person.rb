class Person < ApplicationRecord
  include WorkspaceScoped

  has_many :sessions, dependent: :destroy

  generates_token_for :sign_in, expires_in: 15.minutes do
    last_signed_in_at
  end

  normalizes :email, with: ->(email) { email.strip.downcase.presence }

  validates :name, presence: true
  validates :email, uniqueness: { scope: :workspace_id }, allow_nil: true
  # The first Admin of a new Workspace must be able to sign in, so they need an email then.
  validates :email, presence: true, on: :workspace_creation

  # Signing in consumes a link by stamping last_signed_in_at, which invalidates every link issued before it.
  # The conditional update means two simultaneous uses of one link cannot both succeed.
  def self.sign_in_with_token(token)
    person = find_by_token_for(:sign_in, token)
    return unless person

    updated = where(id: person.id, last_signed_in_at: person.last_signed_in_at)
      .update_all(last_signed_in_at: Time.current)
    person if updated == 1
  end

  def can_sign_in?
    email.present?
  end
end
