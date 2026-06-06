class Music < ApplicationRecord
  belongs_to :band
  has_many :setlist_items, as: :item, dependent: :destroy
  has_many :versions, -> { ordered }, class_name: "MusicVersion", dependent: :destroy
  has_one :primary_version, -> { where(primary: true) }, class_name: "MusicVersion"
  has_many :version_preferences, class_name: "MusicVersionPreference", dependent: :destroy

  serialize :labels, coder: JSON, type: Array

  validates :title, presence: true
  validates :artist, presence: true
  validates :rehearsal_priority, numericality: { only_integer: true, in: 1..10 }, allow_nil: true

  before_validation :normalize_labels
  after_create :ensure_primary_version!
  after_update :sync_primary_version_from_music!, if: :saved_content_change?

  PITCH_CLASSES = %w[C C# D D# E F F# G G# A A# B].freeze
  MODES = { "major" => "Major", "minor" => "Minor" }.freeze

  scope :matching, ->(query) {
    stripped_query = query.to_s.strip
    if stripped_query.present?
      escaped_query = ActiveRecord::Base.sanitize_sql_like(stripped_query)
      where("title LIKE :query OR artist LIKE :query OR labels LIKE :query", query: "%#{escaped_query}%")
    else
      all
    end
  }

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

  def default_version_for(user)
    preference = user&.music_version_preferences&.find_by(music: self)
    preference&.music_version || primary_version || versions.first
  end

  def chords_for(user)
    default_version_for(user)&.chords
  end

  def lyrics_for(user)
    default_version_for(user)&.lyrics
  end

  def has_chords_for?(user)
    chords_for(user).present?
  end

  def display_content_for(user)
    has_chords_for?(user) ? chords_for(user) : lyrics_for(user)
  end

  def version_count
    versions.size
  end

  def rehearsed?
    last_rehearsed_at.present?
  end

  def rehearsal_field_value
    return "" if last_rehearsed_at.blank?
    last_rehearsed_at.strftime("%Y-%m-%d")
  end

  def labels_text
    labels.to_a.join(", ")
  end

  def labels_text=(value)
    self.labels = value.to_s.split(",")
  end

  def label_list
    labels.to_a
  end

  private

  def normalize_labels
    self.labels = labels.to_a
      .flat_map { |label| label.to_s.split(",") }
      .map { |label| label.squish.downcase }
      .reject(&:blank?)
      .uniq
  end

  def saved_content_change?
    previous_changes.key?("chords") || previous_changes.key?("lyrics")
  end

  def ensure_primary_version!
    versions.create!(
      name: "Original",
      chords: chords,
      lyrics: lyrics,
      primary: true
    ) unless versions.exists?
  end

  def sync_primary_version_from_music!
    version = primary_version || versions.first
    version ||= versions.create!(name: "Original", primary: true)

    return if version.chords == chords && version.lyrics == lyrics && version.primary?

    version.update!(chords: chords, lyrics: lyrics, primary: true)
  end
end
