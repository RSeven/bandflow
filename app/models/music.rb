class Music < ApplicationRecord
  belongs_to :band
  has_many :setlist_items, as: :item, dependent: :destroy

  validates :title, presence: true
  validates :artist, presence: true

  PITCH_CLASSES = %w[C C# D D# E F F# G G# A A# B].freeze
  MODES = { "major" => "Major", "minor" => "Minor" }.freeze

  def musical_key
    return nil if key_name.blank?
    mode_label = MODES[key_mode] || key_mode.to_s.capitalize
    "#{key_name} #{mode_label}"
  end

  def bpm_display
    return nil if bpm.blank?
    bpm.to_i.to_s
  end

  def has_chords?
    chords.present?
  end

  def display_content
    has_chords? ? chords : lyrics
  end
end
