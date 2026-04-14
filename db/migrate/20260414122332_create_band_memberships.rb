class CreateBandMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :band_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :band, null: false, foreign_key: true
      t.string :role

      t.timestamps
    end
  end
end
