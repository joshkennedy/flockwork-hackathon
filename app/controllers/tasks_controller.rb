class TasksController < ApplicationController
  before_action :set_project
  before_action :set_task, only: %i[ edit update destroy claim unclaim mark_done reopen ]
  before_action :authorize_manage_tasks, only: %i[ new create edit update destroy ]

  def new
    @task = @project.tasks.build
    @team_people = team_people
  end

  def create
    @task = @project.tasks.build(task_params)
    @team_people = team_people

    if @task.save
      notify_assignee
      redirect_to @project
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @team_people = team_people
  end

  def update
    @team_people = team_people

    if @task.update(task_params)
      notify_assignee
      redirect_to @project
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @task.destroy!
    redirect_to @project
  end

  def claim
    authorize_task_action(:claim_task)
    updated = @project.tasks.where(id: @task.id, assignee_id: nil, completed_at: nil)
      .update_all(assignee_id: Current.person.id, updated_at: Time.current)

    if updated == 1
      redirect_to @project
    else
      redirect_to @project, alert: "That Task is already assigned."
    end
  end

  def unclaim
    authorize_task_action(:unclaim_task)
    @task.update!(assignee: nil)
    redirect_to @project
  end

  def mark_done
    authorize_task_action(:mark_task_done)
    @task.update!(completed_at: Time.current, completed_by: Current.person)
    redirect_to task_redirect_path
  end

  def reopen
    authorize_task_action(:reopen_task)
    @task.update!(completed_at: nil, completed_by: nil)
    redirect_to @project
  end

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def set_task
      @task = @project.tasks.find(params[:id])
    end

    def authorize_manage_tasks
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_tasks, @project)
    end

    def authorize_task_action(action)
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, action, @task)
    end

    def team_people
      @project.people.order(:name)
    end

    def task_params
      params.expect(task: [ :title, :details, :due_on, :assignee_id ])
    end

    def task_redirect_path
      params[:return_to] == "my_tasks" ? my_tasks_path : @project
    end

    def notify_assignee
      return unless @task.assignee_id.present? && @task.previous_changes.key?("assignee_id")

      Notifier.notify(
        recipient: @task.assignee,
        kind: "task_assigned",
        notifiable: @task,
        actor: Current.person
      )
    end
end
