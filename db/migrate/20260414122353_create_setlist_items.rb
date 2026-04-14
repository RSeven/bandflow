class CreateSetlistItems < ActiveRecord::Migration[8.0]
  def change
    create_table :setlist_items do |t|
      t.references :setlist, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.references :item, polymorphic: true, null: false

      t.timestamps
    end
    add_index :setlist_items, [ :setlist_id, :position ]
  end
end
