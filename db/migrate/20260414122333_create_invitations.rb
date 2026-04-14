class CreateInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :invitations do |t|
      t.references :band, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.string :token
      t.string :email_address
      t.datetime :used_at

      t.timestamps
    end
    add_index :invitations, :token, unique: true
  end
end
