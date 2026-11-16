class NotesController < ApplicationController
  before_action :set_person_note, only: %i[edit update destroy]
  before_action :authorize_person_note_management, only: %i[edit update destroy]

  def create
    if params[:project_id]
      create_project_note
    else
      create_person_note
    end
  end

  def edit
  end

  def update
    if @note.update(note_params.slice(:body))
      redirect_to person_path(@person), notice: "Saved note."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @note.destroy!
    redirect_to person_path(@person), notice: "Deleted note."
  end

  private
    def set_person_note
      @person = Current.organization.people.find(params[:person_id])
      @note = @person.notes.find(params[:id])
    end

    def authorize_person_note_management
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_person_note, @note)
    end

    def create_project_note
      project = Policy.visible_projects(Current.person).find(params[:project_id])
      notable = find_project_notable(project)
      note = Current.organization.notes.build(note_params.except(:notable_type, :notable_id).merge(
        notable: notable,
        author: Current.person
      ))
      authorize_note(note)
      save_note(note, project_path(project))
    end

    def create_person_note
      person = Current.organization.people.find(params[:person_id])
      note = Current.organization.notes.build(note_params.except(:notable_type, :notable_id).merge(
        notable: person,
        author: Current.person
      ))
      authorize_note(note)
      save_note(note, person_path(person))
    end

    def find_project_notable(project)
      case note_params[:notable_type]
      when "Project"
        raise ActiveRecord::RecordNotFound unless note_params[:notable_id].to_i == project.id

        project
      when "Recipient"
        project.recipients.find(note_params[:notable_id])
      else
        raise ActiveRecord::RecordNotFound
      end
    end

    def authorize_note(note)
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :write_note, note)
    end

    def save_note(note, redirect_path)
      if note.save
        redirect_to redirect_path
      else
        redirect_to redirect_path, alert: note.errors.full_messages.to_sentence
      end
    end

    def note_params
      params.expect(note: [ :notable_type, :notable_id, :visibility, :body ])
    end
end
