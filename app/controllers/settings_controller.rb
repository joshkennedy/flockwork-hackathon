class SettingsController < ApplicationController
  include AdminOnly
  authorize_admin_with :manage_settings

  def show
  end

  def update
    if Current.organization.update(settings_params)
      redirect_to settings_path
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    # A preset radio and the custom field share one form; "custom" means use the typed hex.
    def settings_params
      choice = params.require(:organization).fetch(:mark_color_choice, "")
      { mark_color: choice == "custom" ? params[:organization][:custom_mark_color].to_s : choice }
    end
end
