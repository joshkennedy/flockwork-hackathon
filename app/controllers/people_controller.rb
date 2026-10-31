class PeopleController < ApplicationController
  before_action :authorize_people_management

  def index
    @people = Current.organization.people.order(:name)
  end

  def new
    @person = Current.organization.people.build
  end

  def create
    @person = Current.organization.people.build(person_params)

    if @person.save
      redirect_to people_path, notice: "Added #{@person.name}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @person = Current.organization.people.find(params[:id])
    load_notes
    load_involvement
  end

  def update
    @person = Current.organization.people.find(params[:id])

    if @person.update(person_params)
      redirect_to people_path, notice: "Saved #{@person.name}."
    else
      load_notes
      load_involvement
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def authorize_people_management
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_people, Current.organization)
    end

    def authorize_involvement
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :view_involvement, @person)
    end

    def load_involvement
      authorize_involvement
      @involvement = Oversight.involvement(@person)
    end

    def person_params
      params.require(:person).permit(:name, :email, :phone, :admin)
    end

    def load_notes
      @person_notes = Policy.visible_notes(Current.person, @person.notes).includes(:author).order(:created_at, :id)
      @note_visibilities = Policy.writable_note_visibilities(Current.person, @person)
    end
end
