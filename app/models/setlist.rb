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
end
