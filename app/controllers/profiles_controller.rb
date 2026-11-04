class ProfilesController < ApplicationController
  def edit
    @person = Current.person
    load_involvement
    load_away_dates
  end

  def update
    @person = Current.person

    if @person.update(profile_params)
      redirect_to home_path, notice: "Your profile was updated."
    else
      load_involvement
      load_away_dates
      render :edit, status: :unprocessable_entity
    end
  end

  # Proposes date ranges from the person's own words. Nothing is saved until they confirm the ranges.
  def suggest_away
    @person = Current.person

    if params[:away_text].to_s.squish.blank?
      @away_alert = "Say when you're away, or enter the dates below."
    else
      begin
        @away_drafts = AwayDateParser.call(params[:away_text]).map { |range| Unavailability.new(range) }
        @away_notice = "Check these dates, then save them."
      rescue AwayDateParser::Unavailable
        @away_alert = "Couldn't turn that into dates. Enter them below."
      end
    end

    load_involvement
    load_away_dates
    render :edit
  end

  private
    def load_involvement
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :view_involvement, @person)

      @involvement = Oversight.involvement(@person)
    end

    def load_away_dates
      @away_dates = @person.unavailabilities.upcoming.to_a
    end

    def profile_params
      permitted = params.require(:person).permit(
        :name,
        :phone,
        skills: [],
        email_preferences: Notification::KINDS.keys
      )
      preferences = permitted.delete(:email_preferences)
      if preferences
        permitted[:email_preferences] = preferences.to_h.transform_values do |value|
          ActiveModel::Type::Boolean.new.cast(value)
        end
      end
      permitted
    end
end
