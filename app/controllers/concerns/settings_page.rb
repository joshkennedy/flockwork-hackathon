# Settings is one page of tabs fed by several controllers; a failed save re-renders it on the tab that failed.
module SettingsPage
  TABS = %w[ details notifications away appearance church directory ].freeze

  private
    def render_settings(tab, status: :ok)
      @person ||= Current.person
      @settings_tab = tab.presence_in(TABS) || TABS.first
      # Rendered from a form submit (a failed save, away suggestions): show that tab, not the remembered one.
      @settings_tab_explicit = action_name != "show"
      @away_dates = @person.unavailabilities.upcoming.to_a
      render "settings/show", status:
    end

    def settings_tab_path(tab)
      settings_path(anchor: "settings-#{tab}")
    end
end
