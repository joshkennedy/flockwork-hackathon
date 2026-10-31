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
      @overextended_people = Oversight.overextended(Current.organization).load
      @never_asked_people = Oversight.never_asked(Current.organization).load
      @involvement_year = Time.current.year
      @involvement = Oversight.involvement_list(Current.organization, @involvement_year)
    end

    def oversight_params
      params.expect(organization: [ :overextended_limit ])
    end
end
