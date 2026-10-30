class ProfilesController < ApplicationController
  include WorkspaceAccess

  def edit
    @person = Current.person
    load_involvement
  end

  def update
    @person = Current.person

    if @person.update(profile_params)
      redirect_to workspace_path(Current.workspace), notice: "Your profile was updated."
    else
      load_involvement
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def load_involvement
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :view_involvement, @person)

      @involvement = Oversight.involvement(@person)
    end

    def profile_params
      permitted = params.require(:person).permit(
        :name,
        :phone,
        email_preferences: Notification::KINDS.keys
      )
      preferences = permitted.delete(:email_preferences)
      if preferences
        permitted[:email_preferences] = preferences.to_h.transform_values do |value|
          ActiveModel::Type::Boolean.new.cast(value)
        end
      end
      permitted
    end
end
