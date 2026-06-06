class Setlist < ApplicationRecord
  belongs_to :band
  has_many :setlist_items, -> { order(:position) }, dependent: :destroy
  has_many :musics, through: :setlist_items, source: :item, source_type: "Music"

  validates :title, presence: true

  def ordered_items
    setlist_items.includes(:item).order(:position)
  end

  def music_items
    setlist_items.where(item_type: "Music").includes(:item).order(:position)
  end

  def music_count
    setlist_items.where(item_type: "Music").count
  end

  def copy_with_items(title:)
    self.class.transaction do
      copy = band.setlists.create!(
        title: title,
        performance_date: performance_date,
        notes: notes
      )

      ordered_items.each do |setlist_item|
        copy.setlist_items.create!(
          item: setlist_item.item,
          position: setlist_item.position
        )
      end

      copy
    end
  end
end
