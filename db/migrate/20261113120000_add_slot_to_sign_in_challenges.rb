class AddSlotToSignInChallenges < ActiveRecord::Migration[8.1]
  def change
    add_reference :sign_in_challenges, :slot, foreign_key: { on_delete: :nullify }
  end
end
