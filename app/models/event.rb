class Event < ApplicationRecord
  belongs_to :band
  has_many :setlist_items, as: :item, dependent: :destroy

  validates :title, presence: true
end
