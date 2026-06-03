class AddLabelsToMusics < ActiveRecord::Migration[8.1]
  def change
    add_column :musics, :labels, :text
  end
end
