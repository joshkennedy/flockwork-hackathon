class OversightsController < ApplicationController
  before_action :authorize_oversight

  def show
    load_oversight
  end

  def update
    if Current.organization.update(oversight_params)
      redirect_to oversight_path, notice: "Oversight settings saved."
    else
      load_oversight
      render :show, status: :unprocessable_content
    end
  end

  private
    def authorize_oversight
      action = action_name == "update" ? :update_oversight : :view_oversight
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, action, Current.organization)
    end

    def load_oversight
      today = Date.current
      @overextended_people = Oversight.needs_check_in(Current.organization, on: today).load
      @last_check_ins = CheckIn.where(organization: Current.organization).latest_by_person(@overextended_people.map(&:id))
      @summaries = @overextended_people.map do |person|
        facts = OversightSummary.facts_for(person, last_check_in: @last_check_ins[person.id])
        [ person.id, OversightSummary.template(facts) ]
      end.to_h
      @never_asked_people = Oversight.never_asked(Current.organization).load
      @away_ranges = Oversight.upcoming_away(Current.organization, today: today).to_a
      @involvement_year = Time.current.year
      # Settings and the cross-church involvement table are Admin-only; Leaders see the urgent lists.
      @involvement = Oversight.involvement_list(Current.organization, @involvement_year) if Current.person.admin?
    end

    def oversight_params
      params.expect(organization: [ :overextended_limit ])
    end
end
