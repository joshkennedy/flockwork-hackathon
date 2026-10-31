class GetInvolvedController < ApplicationController
  def show
    @projects = Current.organization.projects.active.where(open_team: true).order(:name)
  end
end
