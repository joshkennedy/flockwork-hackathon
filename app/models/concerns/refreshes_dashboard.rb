module RefreshesDashboard
  extend ActiveSupport::Concern

  included do
    after_commit :refresh_dashboard
  end

  private
    def refresh_dashboard
      organization_id = if is_a?(Project)
        self.organization_id
      elsif is_a?(SlotClaim)
        slot&.project&.organization_id
      else
        project&.organization_id
      end
      organization = Organization.find_by(id: organization_id) if organization_id
      # Only an invalidation travels here. Each viewer reloads through the current access policy.
      Turbo::StreamsChannel.broadcast_refresh_to(organization, :dashboard) if organization
    end
end
