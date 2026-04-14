class CreateMusics < ActiveRecord::Migration[8.0]
  def change
    create_table :musics do |t|
      t.references :band, null: false, foreign_key: true
      t.string :title
      t.string :artist
      t.text :lyrics
      t.text :chords
      t.string :spotify_url
      t.string :youtube_url
      t.string :spotify_track_id
      t.decimal :bpm, precision: 5, scale: 1
      t.string :key_name
      t.string :key_mode

      t.timestamps
    end
    add_index :musics, [ :band_id, :title ]
  end
end
