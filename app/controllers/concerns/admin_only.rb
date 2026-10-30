module AdminOnly
  extend ActiveSupport::Concern

  included do
    before_action :require_admin
  end

  private
    def require_admin
      raise ActiveRecord::RecordNotFound unless Current.person&.admin?
    end
end
