class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :person, to: :session, allow_nil: true
  delegate :organization, to: :person, allow_nil: true
end
