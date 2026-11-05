class Session < ApplicationRecord
  belongs_to :person

  def organization_choice_eligible?
    auth_method.in?(%w[ magic_link org_choice ]) && verified_email.present? && verified_email == person.email
  end
end
