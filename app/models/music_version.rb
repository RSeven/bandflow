class MusicVersion < ApplicationRecord
  belongs_to :music
  has_many :preferences, class_name: "MusicVersionPreference", dependent: :destroy

  validates :name, presence: true

  before_validation :set_default_primary, on: :create
  before_update :keep_one_primary
  after_save :demote_other_versions, if: :saved_change_to_primary?
  after_save :sync_music_content, if: :primary?
  after_destroy :promote_fallback_version, if: :primary?

  scope :ordered, -> { order(primary: :desc, created_at: :asc, id: :asc) }

  def has_chords?
    chords.present?
  end

  def display_content
    has_chords? ? chords : lyrics
  end

  private

  def set_default_primary
    self.primary = true unless music&.versions&.exists?
  end

  def keep_one_primary
    return if primary?
    return if music.versions.where.not(id: id).where(primary: true).exists?

    self.primary = true
  end

  def demote_other_versions
    return unless primary?

    music.versions.where.not(id: id).update_all(primary: false, updated_at: Time.current)
  end

  def sync_music_content
    music.update_columns(chords: chords, lyrics: lyrics, updated_at: Time.current)
  end

  def promote_fallback_version
    fallback = music.versions.order(created_at: :asc, id: :asc).first

    if fallback
      fallback.update!(primary: true)
    else
      music.update_columns(chords: nil, lyrics: nil, updated_at: Time.current)
    end
  end
end
