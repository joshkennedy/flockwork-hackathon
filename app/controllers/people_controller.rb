class PeopleController < ApplicationController
  include WorkspaceAccess
  include AdminOnly

  def index
    @people = Current.workspace.people.order(:name)
  end

  def new
    @person = Current.workspace.people.build
  end

  def create
    @person = Current.workspace.people.build(person_params)

    if @person.save
      redirect_to people_path(Current.workspace), notice: "Added #{@person.name}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @person = Current.workspace.people.find(params[:id])
    load_notes
  end

  def update
    @person = Current.workspace.people.find(params[:id])

    if @person.update(person_params)
      redirect_to people_path(Current.workspace), notice: "Saved #{@person.name}."
    else
      load_notes
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def person_params
      params.require(:person).permit(:name, :email, :phone, :admin)
    end

    def load_notes
      @person_notes = Policy.visible_notes(Current.person, @person.notes).includes(:author).order(:created_at, :id)
      @note_visibilities = Policy.writable_note_visibilities(Current.person, @person)
    end
end
