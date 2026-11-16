# Lets someone whose email belongs to a Person in more than one Organization pick which one to work in.
# The sign-in link already proved they own the email, so any Person sharing it is theirs to switch to.
class OrganizationChoicesController < ApplicationController
  def new
    @people = choosable_people.includes(:organization).sort_by { |person| person.organization.name }
  end

  def create
    person = choosable_people.find(params[:person_id])
    verified_email = Current.session.verified_email
    terminate_session
    start_new_session_for person, auth_method: "org_choice", verified_email: verified_email
    redirect_to home_path
  end

  private
    def choosable_people
      raise ActiveRecord::RecordNotFound unless Current.session.organization_choice_eligible?

      Person.active.where(email: Current.session.verified_email)
    end
end
