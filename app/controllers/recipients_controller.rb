class RecipientsController < ApplicationController
  before_action :set_project
  before_action :set_recipient, only: :destroy
  before_action :authorize_manage_recipients

  def new
    load_directory_people if params[:query].present?
  end

  def create
    person = find_or_create_person

    if person.is_a?(Person) && person.errors.any?
      load_directory_people if params[:query].present?
      @person = person
      render :new, status: :unprocessable_content
      return
    end

    recipient = @project.recipients.build(person: person)

    if recipient.save
      redirect_to @project
    else
      @person = person
      @recipient = recipient
      load_directory_people if params[:query].present?
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    @recipient.destroy!
    redirect_to @project
  end

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def set_recipient
      @recipient = @project.recipients.find(params[:id])
    end

    def authorize_manage_recipients
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_recipients, @project)
    end

    def find_or_create_person
      if params[:person_id].present?
        return Current.organization.people.find(params[:person_id])
      end

      person = Current.organization.people.build(new_person_params)
      person.save ? person : person
    end

    def load_directory_people
      recipient_ids = @project.recipients.select(:person_id)
      member_ids = @project.memberships.select(:person_id)

      @directory_people = Current.organization.people
        .where("name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(params[:query])}%")
        .where.not(id: recipient_ids)
        .where.not(id: member_ids)
        .order(:name)
    end

    def new_person_params
      params.expect(person: [ :name, :phone ])
    end
end
