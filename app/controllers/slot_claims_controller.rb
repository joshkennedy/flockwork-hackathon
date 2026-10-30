class SlotClaimsController < ApplicationController
  before_action :set_project
  before_action :set_slot
  before_action :authorize_claim_slot

  def create
    claim = @slot.claim(Current.person)

    if claim&.persisted?
      redirect_to @project
    else
      redirect_to @project, alert: (@slot.errors.full_messages + Array(claim).flat_map { |record| record.errors.full_messages }).to_sentence
    end
  end

  def destroy
    @slot.slot_claims.find_by!(person: Current.person).destroy!
    redirect_to @project
  end

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def set_slot
      @slot = @project.slots.find(params[:slot_id])
    end

    def authorize_claim_slot
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :claim_slot, @project)
    end
end
