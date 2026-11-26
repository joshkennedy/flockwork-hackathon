# Sends every successful change a signed-in Person makes to analytics, named like "Slot claim created".
module TracksActivity
  extend ActiveSupport::Concern

  VERBS = { "create" => "created", "update" => "updated", "destroy" => "deleted" }.freeze

  included do
    after_action :track_activity, unless: -> { request.get? || request.head? }
  end

  private
    def track_activity
      return unless Current.person && (response.successful? || response.redirect?)

      verb = VERBS.fetch(action_name) { action_name.humanize(capitalize: false) }
      Analytics.capture(Current.person, "#{controller_name.singularize.humanize} #{verb}", controller: controller_path, action: action_name)
    end
end
