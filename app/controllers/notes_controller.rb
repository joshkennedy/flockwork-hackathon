class NotesController < ApplicationController
  def create
    if params[:project_id]
      create_project_note
    else
      create_person_note
    end
  end

  private
    def create_project_note
      project = Policy.visible_projects(Current.person).find(params[:project_id])
      notable = find_project_notable(project)
      note = Current.workspace.notes.build(note_params.except(:notable_type, :notable_id).merge(
        notable: notable,
        author: Current.person
      ))
      authorize_note(note)
      save_note(note, project_path(project))
    end

    def create_person_note
      raise ActiveRecord::RecordNotFound unless params[:workspace_slug] == Current.workspace.slug

      person = Current.workspace.people.find(params[:person_id])
      note = Current.workspace.notes.build(note_params.except(:notable_type, :notable_id).merge(
        notable: person,
        author: Current.person
      ))
      authorize_note(note)
      save_note(note, edit_person_path(Current.workspace, person))
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
