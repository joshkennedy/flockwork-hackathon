module AdminOnly
  extend ActiveSupport::Concern

  included do
    class_attribute :admin_policy_action, instance_accessor: false, default: :manage_people
    before_action :require_admin
  end

  class_methods do
    def authorize_admin_with(action)
      self.admin_policy_action = action
    end
  end

  private
    def require_admin
      authorized = Current.person && Current.workspace &&
        Policy.can?(Current.person, self.class.admin_policy_action, Current.workspace)
      raise ActiveRecord::RecordNotFound unless authorized
    end
end
