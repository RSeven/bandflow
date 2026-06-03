class AddRehearsalPriorityToMusics < ActiveRecord::Migration[8.0]
  def change
    add_column :musics, :rehearsal_priority, :integer
  end
end
