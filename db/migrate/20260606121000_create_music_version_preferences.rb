class CreateMusicVersionPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :music_version_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.references :music, null: false, foreign_key: true
      t.references :music_version, null: false, foreign_key: true

      t.timestamps
    end

    add_index :music_version_preferences, [ :user_id, :music_id ], unique: true
  end
end
