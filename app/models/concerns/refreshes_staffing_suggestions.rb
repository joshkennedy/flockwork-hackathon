module RefreshesStaffingSuggestions
  extend ActiveSupport::Concern

  included do
    after_save_commit :refresh_staffing_suggestions, if: :saved_change_to_skills?
  end

  private
    def refresh_staffing_suggestions
      changed_skills = saved_change_to_skills.flatten.compact.uniq
      return if changed_skills.empty?

      Project.active.where(organization_id: organization_id)
        .where("skills_needed && ARRAY[?]::varchar[]", changed_skills).find_each(&:broadcast_refresh)
    end
end
