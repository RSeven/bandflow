class CreateMusicVersions < ActiveRecord::Migration[8.1]
  class MigrationMusic < ActiveRecord::Base
    self.table_name = "musics"
  end

  class MigrationMusicVersion < ActiveRecord::Base
    self.table_name = "music_versions"
  end

  def up
    create_table :music_versions do |t|
      t.references :music, null: false, foreign_key: true
      t.string :name, null: false, default: "Original"
      t.text :chords
      t.text :lyrics
      t.boolean :primary, null: false, default: false

      t.timestamps
    end

    add_index :music_versions, [ :music_id, :primary ], name: "index_music_versions_on_music_id_and_primary"

    MigrationMusic.find_each do |music|
      MigrationMusicVersion.create!(
        music_id: music.id,
        name: "Original",
        chords: music.chords,
        lyrics: music.lyrics,
        primary: true,
        created_at: Time.current,
        updated_at: Time.current
      )
    end
  end

  def down
    drop_table :music_versions
  end
end
