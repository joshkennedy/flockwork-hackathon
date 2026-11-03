class UnavailabilitiesController < ApplicationController
  def create
    drafts = params.expect(unavailabilities: [ %i[ starts_on ends_on note ] ]).map do |attributes|
      Unavailability.new(attributes.merge(person: Current.person, organization: Current.organization))
    end

    if drafts.map(&:valid?).all?
      Unavailability.transaction { drafts.each(&:save!) }
      redirect_to edit_profile_path, notice: "Saved #{drafts.size == 1 ? "your away dates" : "#{drafts.size} away ranges"}."
    else
      redirect_to edit_profile_path, alert: drafts.flat_map { |draft| draft.errors.full_messages }.uniq.to_sentence
    end
  end

  def destroy
    unavailability = Unavailability.where(organization: Current.organization).find(params[:id])
    raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :destroy, unavailability)

    unavailability.destroy!
    redirect_to edit_profile_path, notice: "Removed away dates."
  end
end
