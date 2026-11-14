class PeopleController < ApplicationController
  before_action :authorize_people_management
  rate_limit to: 5, within: 10.minutes, by: -> { Current.session.id }, name: "demo_session",
    scope: "demo_outbound_actions", only: :create, if: :demo_organization?, with: :person_create_rate_limited
  rate_limit to: 20, within: 10.minutes, by: -> { request.remote_ip }, name: "demo_ip",
    scope: "demo_outbound_actions", only: :create, if: :demo_organization?, with: :person_create_rate_limited

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
    @filter_tabs = FILTERS.map { |key, (label, _scope)| [ key, label, @filter_counts.fetch(key) ] }

    @skill = Skills.normalize(params[:skill]).first
    @skill_options = (people.pluck(:skills).flatten + Array(@skill)).uniq.sort
    matches = people.matching(params[:query])
    matches = matches.where("? = ANY(people.skills)", @skill) if @skill
    scope = FILTERS.fetch(@filter).last
    matches = matches.public_send(scope) if scope
    @people = matches.includes(:added_by).order(:name).to_a
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

    @person.assign_attributes(person_params.except(:email))
    send_confirmation = stage_email_change

    if @person.save
      if send_confirmation && DemoOutboundLimit.allow?(@person.organization)
        SignInMailer.email_change(@person).deliver_later
      end
      flash[:notice] = "Saved #{@person.name}."
      # From the slideout, refresh the person page underneath; errors re-render inside the panel.
      # request_id: nil, because Turbo ignores a refresh stamped with the request that caused it.
      if turbo_frame_request?
        render turbo_stream: turbo_stream.refresh(request_id: nil)
      else
        redirect_to person_path(@person)
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def person_create_rate_limited
      @person = Current.organization.people.build(person_params)
      flash.now[:alert] = "Demo limit reached. Try again in 10 minutes."
      render :new, status: :too_many_requests
    end

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

    # A new address is held as pending until its owner confirms by mail; blanking the email takes effect at once.
    # Returns whether a confirmation mail is due once the Person saves.
    def stage_email_change
      return false unless params[:person]&.key?(:email)

      address = Person.normalize_value_for(:email, params[:person][:email].to_s)
      if address.nil?
        @person.assign_attributes(email: nil, pending_email: nil)
        return false
      end
      return false if address == @person.email

      @person.pending_email = address
      true
    end

    def person_params
      params.require(:person).permit(:name, :email, :phone, :admin, skills: [])
    end
end
