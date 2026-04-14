class CreateSetlists < ActiveRecord::Migration[8.0]
  def change
    create_table :setlists do |t|
      t.references :band, null: false, foreign_key: true
      t.string :title
      t.date :performance_date
      t.text :notes

      t.timestamps
    end
  end
end
