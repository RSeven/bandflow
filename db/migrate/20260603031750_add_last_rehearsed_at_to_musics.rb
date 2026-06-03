class AddLastRehearsedAtToMusics < ActiveRecord::Migration[8.1]
  def change
    add_column :musics, :last_rehearsed_at, :date
    add_index :musics, [ :band_id, :last_rehearsed_at ]
  end
end
