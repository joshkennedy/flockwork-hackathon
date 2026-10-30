class GetInvolvedController < ApplicationController
  def show
    @projects = Current.workspace.projects.active.where(open_team: true).order(:name)
  end
end
