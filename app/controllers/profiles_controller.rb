class ProfilesController < ApplicationController
  include SettingsPage

  rate_limit to: 20, within: 1.hour, by: -> { Current.person.id }, only: :suggest_away, with: :suggest_away_rate_limited
  rate_limit to: 5, within: 10.minutes, by: -> { Current.session.id }, name: "demo_session",
    scope: "demo_outbound_actions", only: :update, if: :demo_phone_change?
  rate_limit to: 20, within: 10.minutes, by: -> { request.remote_ip }, name: "demo_ip",
    scope: "demo_outbound_actions", only: :update, if: :demo_phone_change?

  # Your own involvement, read-only; what you can change lives on Settings.
  def show
    @person = Current.person
    raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :view_involvement, @person)

    @involvement = Oversight.involvement(@person)
  end

  def update
    @person = Current.person
    tab = params[:tab].presence_in(%w[ details notifications ]) || "details"
    @person.assign_attributes(profile_params.except(:email))
    email_change = stage_email_change

    if email_change == :invalid
      render_settings(tab, status: :unprocessable_entity)
    elsif @person.save
      if email_change && DemoOutboundLimit.allow?(@person.organization)
        SignInMailer.email_change(@person).deliver_later
      end
      redirect_to settings_tab_path(tab), notice: "Settings saved."
    else
      render_settings(tab, status: :unprocessable_entity)
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

    render_settings("away")
  end

  private
    def demo_phone_change?
      person_params = params[:person]
      demo_organization? && person_params.respond_to?(:key?) && person_params.key?(:phone) &&
        person_params[:phone].to_s != Current.person.phone.to_s
    end

    def suggest_away_rate_limited
      if request.format.json?
        render json: { error: "Too many suggestions. Try again in an hour." }, status: :too_many_requests
        return
      end

      @person = Current.person
      flash.now[:alert] = "Too many suggestions. Try again in an hour."
      render_settings("away", status: :too_many_requests)
    end

    def profile_params
      permitted = params.require(:person).permit(
        :name,
        :email,
        :phone,
        skills: [],
        # The weekly Project email is an email preference without a Notification kind.
        **Person::NOTIFICATION_CHANNELS.values.index_with { Notification::KINDS.keys }
          .merge(email_preferences: [ *Notification::KINDS.keys, "weekly_project_digest" ])
      )
      Person::NOTIFICATION_CHANNELS.each_value do |attribute|
        preferences = permitted.delete(attribute)
        next unless preferences

        permitted[attribute] = @person.public_send(attribute).merge(preferences.to_h.transform_values do |value|
          ActiveModel::Type::Boolean.new.cast(value)
        end)
      end
      permitted
    end

    def stage_email_change
      return false unless params[:person]&.key?(:email)

      address = Person.normalize_value_for(:email, params[:person][:email].to_s)
      if address.nil?
        @person.errors.add(:email, "can't be blank")
        return :invalid
      end
      return false if address == @person.email

      @person.pending_email = address
      true
    end
end
