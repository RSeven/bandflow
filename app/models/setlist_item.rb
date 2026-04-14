class SetlistItem < ApplicationRecord
  belongs_to :setlist
  belongs_to :item, polymorphic: true

  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_create :set_position

  def music?
    item_type == "Music"
  end

  def event?
    item_type == "Event"
  end

  # Returns the 1-based music index among only music items (ignoring events)
  def music_index
    return nil unless music?
    setlist.setlist_items
           .where(item_type: "Music")
           .where("position <= ?", position)
           .count
  end

  private

  def set_position
    return if position.present? && position != 0
    max = setlist.setlist_items.maximum(:position) || -1
    self.position = max + 1
  end
end
