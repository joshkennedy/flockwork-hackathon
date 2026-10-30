class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :recipient, null: false, foreign_key: { to_table: :people }
      t.integer :kind, null: false
      t.references :notifiable, polymorphic: true, null: false
      t.references :actor, foreign_key: { to_table: :people }
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [ :recipient_id, :read_at ]
    add_column :people, :email_preferences, :jsonb, null: false, default: {}
  end
end
