module WorkspaceScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :workspace

    scope :for_workspace, ->(workspace) { where(workspace:) }
  end
end
