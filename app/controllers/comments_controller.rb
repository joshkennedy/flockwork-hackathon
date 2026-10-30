class CommentsController < ApplicationController
  COMMENTABLE_ASSOCIATIONS = {
    "BudgetLine" => :budget_lines,
    "DocItem" => :doc_items,
    "ListRow" => :list_rows,
    "ScheduleItem" => :schedule_items,
    "Slot" => :slots,
    "Task" => :tasks
  }.freeze

  before_action :set_project
  before_action :authorize_comment

  def create
    commentable = commentable_from_params
    comment = commentable.comments.build(comment_params)
    comment.author = Current.person

    if comment.save
      redirect_to @project
    else
      redirect_to @project, alert: comment.errors.full_messages.to_sentence
    end
  end

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def authorize_comment
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :comment, @project)
    end

    def commentable_from_params
      association = COMMENTABLE_ASSOCIATIONS[comment_params[:commentable_type]]
      raise ActiveRecord::RecordNotFound unless association

      @project.public_send(association).find(comment_params[:commentable_id])
    end

    def comment_params
      params.expect(comment: [ :commentable_type, :commentable_id, :body ])
    end
end
