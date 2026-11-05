class Session < ApplicationRecord
  belongs_to :person

  after_destroy_commit :disconnect_cable

  def disconnect_cable
    ActionCable.server.remote_connections.where(current_session: self).disconnect
  end

  def organization_choice_eligible?
    auth_method.in?(%w[ magic_link org_choice ]) && verified_email.present? && verified_email == person.email
  end
end
