class MessagesController < ApplicationController
  before_action :set_project
  before_action :set_message, only: %i[ edit update destroy ]
  before_action :authorize_post_message, only: %i[ create ]
  before_action :authorize_edit_message, only: %i[ edit update ]
  before_action :authorize_delete_message, only: %i[ destroy ]

  def create
    attributes = create_message_params
    parent_id = attributes.delete(:parent_id)
    @message = @project.messages.build(attributes)
    @message.parent = @project.messages.find(parent_id) if parent_id.present?
    @message.author = Current.person

    if @message.save
      @message.notify_team
      redirect_to @project
    else
      redirect_to @project, alert: @message.errors.full_messages.to_sentence
    end
  end

  def edit
  end

  def update
    if @message.update(update_message_params)
      redirect_to @project
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @message.destroy!
    redirect_to @project
  end

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def set_message
      @message = @project.messages.find(params[:id])
    end

    def authorize_post_message
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :post_message, @project)
    end

    def authorize_edit_message
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :edit_message, @message)
    end

    def authorize_delete_message
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :delete_message, @message)
    end

    def create_message_params
      params.expect(message: [ :body, :parent_id ])
    end

    def update_message_params
      params.expect(message: [ :body ])
    end
end
