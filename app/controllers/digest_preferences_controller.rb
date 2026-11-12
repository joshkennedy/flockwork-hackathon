class DigestPreferencesController < ApplicationController
  def show
    @person = Current.person
  end

  def update
    @person = Current.person
    enabled = ActiveModel::Type::Boolean.new.cast(params.require(:digest).fetch(:enabled, "0"))
    saved = @person.with_lock do
      @person.update(email_preferences: @person.email_preferences.merge("weekly_project_digest" => enabled))
    end

    if saved
      redirect_to digest_preferences_path, notice: "Weekly email preference saved."
    else
      render :show, status: :unprocessable_entity
    end
  end
end
