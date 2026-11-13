class SettingsController < ApplicationController
  include SettingsPage

  before_action :require_settings_admin, only: :update

  def show
    render_settings("details")
  end

  def update
    if Current.organization.update(church_params)
      redirect_to settings_tab_path("church"), notice: ("Church settings saved." unless theme_pick?)
    else
      render_settings("church", status: :unprocessable_entity)
    end
  end

  private
    def require_settings_admin
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_settings, Current.organization)
    end

    def theme_pick?
      params[:organization]&.key?(:mark_color_choice)
    end

    # A preset radio and the custom field share one form; "custom" means use the typed hex.
    def church_params
      permitted = params.require(:organization).permit(:name, :overextended_limit)
      if theme_pick?
        choice = params[:organization][:mark_color_choice].to_s
        permitted[:mark_color] = choice == "custom" ? params[:organization][:custom_mark_color].to_s : choice
      end
      permitted
    end
end
