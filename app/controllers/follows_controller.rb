class FollowsController < ApplicationController
  before_action :set_project
  before_action :set_follow

  def destroy
    raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :unfollow, @follow)

    @follow.destroy!
    redirect_to @project
  end

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def set_follow
      @follow = Current.person.follows.find(params[:id])
      raise ActiveRecord::RecordNotFound unless @follow.followable.project == @project
    end
end
