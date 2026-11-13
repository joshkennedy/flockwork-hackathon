class AddSignedInAtToSignInChallenges < ActiveRecord::Migration[8.1]
  def change
    add_column :sign_in_challenges, :signed_in_at, :datetime
  end
end
