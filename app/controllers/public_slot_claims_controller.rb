# Claims made from the Public page by someone who is signed in but may not be on the Team.
class PublicSlotClaimsController < ApplicationController
  before_action :set_slot

  def create
    claim = @slot.claim(Current.person, **claim_params)
    alert = (@slot.errors.full_messages + Array(claim).flat_map { |record| record.errors.full_messages }).to_sentence
    redirect_to public_project_path(@project.public_token, anchor: helpers.dom_id(@slot)), alert: alert.presence
  end

  def update
    claim = @slot.slot_claims.find_by!(person: Current.person)
    alert = claim.errors.full_messages.to_sentence unless claim.update(claim_params)
    redirect_to public_project_path(@project.public_token, anchor: helpers.dom_id(@slot)), alert:
  end

  def destroy
    @slot.slot_claims.find_by!(person: Current.person).destroy!
    redirect_to public_project_path(@project.public_token, anchor: helpers.dom_id(@slot))
  end

  private
    def set_slot
      @project = Project.publicly_linked.find_by!(public_token: params[:token])
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :claim_public_slot, @project)
      raise ActiveRecord::RecordNotFound unless @project.enabled_tools.include?("signup_sheet")

      @slot = @project.slots.find(params[:slot_id])
    end

    def claim_params
      params.fetch(:slot_claim, ActionController::Parameters.new).permit(:note).to_h.symbolize_keys
    end
end
