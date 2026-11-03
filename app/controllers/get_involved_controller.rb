class GetInvolvedController < ApplicationController
  def show
    @projects = Current.organization.projects.active.where(open_team: true).with_attached_banner.order(:name)
    @joined_ids = Membership.where(person: Current.person, project: @projects).pluck(:project_id)
    slots = Slot.where(project: @projects).where(date: Date.current..).chronological.includes(:project, slot_claims: :person).to_a
    @slots_by_project = slots.group_by(&:project_id)
    # A full Slot stays listed once this person has filled it, so their own commitment doesn't vanish.
    @needs = slots.select { |slot| !slot.full? || slot.slot_claims.any? { |claim| claim.person_id == Current.person.id } }
  end
end
