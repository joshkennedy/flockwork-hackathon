class MembershipsController < ApplicationController
  def destroy
    project = Policy.visible_projects(Current.person).find(params[:project_id])
    membership = project.memberships.find(params[:id])
    action = membership.person_id == Current.person.id ? :leave_team : :remove_member
    raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, action, membership)

    membership.destroy!

    if action == :leave_team
      redirect_to projects_path, notice: "You left #{project.name}."
    else
      redirect_to team_project_path(project), notice: "Removed #{membership.person.name} from the Team."
    end
  end
end
