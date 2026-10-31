# Lets someone whose email belongs to a Person in more than one Workspace pick which one to work in.
# The sign-in link already proved they own the email, so any Person sharing it is theirs to switch to.
class WorkspaceChoicesController < ApplicationController
  def new
    @people = choosable_people.includes(:workspace).sort_by { |person| person.workspace.name }
  end

  def create
    person = choosable_people.find(params[:person_id])
    terminate_session
    start_new_session_for person
    redirect_to home_path
  end

  private
    def choosable_people
      Person.where(email: Current.person.email).where.not(email: nil)
    end
end
