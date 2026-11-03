class CheckInsController < ApplicationController
  def create
    person = Current.organization.people.find(params[:person_id])
    raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :log_check_in, person)

    attributes = params.expect(check_in: [ :on, :note ])
    check_in = person.check_ins.build(
      organization: Current.organization,
      checked_in_by: Current.person,
      on: attributes[:on].presence || Date.current,
      note: attributes[:note].presence
    )

    # The person page logs from its own Check-ins section; Oversight is the default.
    redirect_path = params[:return_to] == "person" ? person_path(person) : oversight_path
    if check_in.save
      redirect_to redirect_path, notice: "Logged a check-in with #{person.name}. They leave this list for #{CheckIn::RECENT_DAYS} days."
    else
      redirect_to redirect_path, alert: check_in.errors.full_messages.to_sentence
    end
  end
end
