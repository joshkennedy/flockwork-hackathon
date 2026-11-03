class PeopleController < ApplicationController
  before_action :authorize_people_management

  # Quick filters on the directory: each is a Person scope, and its count is for the whole church.
  FILTERS = {
    "everyone" => [ "Everyone", nil ],
    "serving" => [ "Serving now", :serving_now ],
    "leaders" => [ "Leaders", :leading ],
    "not_yet_asked" => [ "Not yet asked", :never_asked ],
    "away" => [ "Away", :away_on ],
    "no_email" => [ "No email", :without_email ]
  }.freeze

  def index
    people = Current.organization.people
    @filter = FILTERS.key?(params[:filter]) ? params[:filter] : "everyone"
    @filter_counts = FILTERS.to_h { |key, (_label, scope)| [ key, scope ? people.public_send(scope).count : people.count ] }
    @people_count = @filter_counts.fetch("everyone")
    @filter_tabs = FILTERS.map { |key, (label, _scope)| [ key, label, @filter_counts.fetch(key) ] }

    matches = people.matching(params[:query])
    scope = FILTERS.fetch(@filter).last
    matches = matches.public_send(scope) if scope
    @people = matches.order(:name).to_a
    load_directory_rows(@people.map(&:id))
  end

  def show
    @person = Current.organization.people.find(params[:id])
    load_involvement
    load_person_page
    load_notes
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
  end

  def update
    @person = Current.organization.people.find(params[:id])

    if @person.update(person_params)
      redirect_to people_path, notice: "Saved #{@person.name}."
    else
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

    # Each aggregate is one query for the whole list, so the directory costs the same however many People it shows.
    def load_directory_rows(ids)
      serving = Membership.joins(:project).merge(Project.active).where(person_id: ids)
        .order("projects.name").pluck("memberships.person_id", "memberships.role", "projects.name").group_by(&:first)
      @serving_names = serving.transform_values { |rows| rows.map(&:last) }
      @leader_ids = serving.filter_map { |person_id, rows| person_id if rows.any? { |row| row[1] == "leader" } }.to_set

      slot_dates = SlotClaim.joins(:slot).where(person_id: ids, slots: { date: ..Date.current })
        .group("slot_claims.person_id").maximum("slots.date")
      task_dates = Task.where(completed_by_id: ids).group(:completed_by_id).maximum(:completed_at)
      @last_served = ids.index_with { |id| [ slot_dates[id], task_dates[id]&.to_date ].compact.max }

      @never_asked_ids = Current.organization.people.never_asked.where(id: ids).ids.to_set
      @away_until = Oversight.away_until(Current.organization)
    end

    # The person page reads its own records; the directory's rules are the same scopes, applied to one Person.
    def load_person_page
      memberships = @person.memberships.includes(:project).sort_by { |membership| membership.project.name }
      @serving_memberships, past = memberships.partition { |membership| membership.project.active? }
      @past_memberships = past.reject { |membership| membership.project.deleted_at }
      @leads_active_project = @serving_memberships.any?(&:leader?)
      @never_asked = Current.organization.people.never_asked.exists?(@person.id)
      @away_until = @person.unavailabilities.covering(Date.current).maximum(:ends_on)
      @away_dates = @person.unavailabilities.upcoming.to_a
      @last_check_in = CheckIn.latest_by_person([ @person.id ])[@person.id]
    end

    def load_notes
      @person_notes = Policy.visible_notes(Current.person, @person.notes).includes(:author).order(:created_at, :id)
      @note_visibilities = Policy.writable_note_visibilities(Current.person, @person)
    end

    def person_params
      params.require(:person).permit(:name, :email, :phone, :admin)
    end
end
