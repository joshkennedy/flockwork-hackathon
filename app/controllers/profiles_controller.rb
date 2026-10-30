class ProfilesController < ApplicationController
  include WorkspaceAccess

  def edit
    @person = Current.person
  end

  def update
    @person = Current.person

    if @person.update(profile_params)
      redirect_to workspace_path(Current.workspace), notice: "Your profile was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def profile_params
      params.require(:person).permit(:name, :phone)
    end
end
