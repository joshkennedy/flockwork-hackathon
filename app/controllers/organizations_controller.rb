class OrganizationsController < ApplicationController
  allow_unauthenticated_access only: :create

  def show
    @organization = Current.organization
    @person = Current.person
    @pending_invitations = Policy.visible_invitations(Current.person).includes(:project).order(created_at: :desc)
  end

  def create
    @organization = Organization.new(name: organization_params[:church_name])
    @admin = @organization.people.build(name: organization_params[:your_name], email: organization_params[:email], admin: true)

    if @admin.valid?(:organization_creation) && @organization.save
      start_new_session_for @admin
      redirect_to home_path
    else
      redirect_to root_path, alert: (@organization.errors.full_messages + @admin.errors.full_messages).to_sentence
    end
  end

  private
    def organization_params
      params.permit(:church_name, :your_name, :email)
    end
end
