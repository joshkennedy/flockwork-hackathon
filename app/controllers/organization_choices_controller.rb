# Lets someone whose email belongs to a Person in more than one Organization pick which one to work in.
# The sign-in link already proved they own the email, so any Person sharing it is theirs to switch to.
class OrganizationChoicesController < ApplicationController
  def new
    @people = choosable_people.includes(:organization).sort_by { |person| person.organization.name }
  end

  def create
    person = choosable_people.find(params[:person_id])
    terminate_session
    start_new_session_for person, auth_method: "org_choice"
    redirect_to home_path
  end

  private
    def choosable_people
      raise ActiveRecord::RecordNotFound unless Current.session.auth_method.in?(%w[ magic_link org_choice ])

      Person.where(email: Current.person.email).where.not(email: nil)
    end
end
