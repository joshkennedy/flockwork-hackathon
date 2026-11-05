class AddAuthMethodToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :auth_method, :string
    add_column :sessions, :verified_email, :string
  end
end
