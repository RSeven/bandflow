class MusicVersionPreference < ApplicationRecord
  belongs_to :user
  belongs_to :music
  belongs_to :music_version

  validates :user_id, uniqueness: { scope: :music_id }
  validate :version_belongs_to_music

  private

  def version_belongs_to_music
    return if music_version.blank? || music_version.music_id == music_id

    errors.add(:music_version, :invalid)
  end
end
