class Current < ActiveSupport::CurrentAttributes
  attribute :session, :demo_visitor
  delegate :person, to: :session, allow_nil: true
  delegate :organization, to: :person, allow_nil: true
end
