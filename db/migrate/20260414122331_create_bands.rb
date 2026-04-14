class CreateBands < ActiveRecord::Migration[8.0]
  def change
    create_table :bands do |t|
      t.string :name
      t.text :description
      t.string :slug

      t.timestamps
    end
    add_index :bands, :slug, unique: true
  end
end
