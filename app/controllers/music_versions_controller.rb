class MusicVersionsController < ApplicationController
  before_action :set_band
  before_action :require_membership
  before_action :set_music
  before_action :set_version, only: [ :edit, :update, :destroy, :make_primary ]

  def new
    @version = @music.versions.new
  end

  def create
    @version = @music.versions.new(version_params)

    if @version.save
      set_user_default(@version) if default_for_current_user?
      redirect_to band_music_path(@band, @music), notice: t("flash.music_versions.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @version.update(version_params)
      set_user_default(@version) if default_for_current_user?
      redirect_to band_music_path(@band, @music), notice: t("flash.music_versions.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @version.destroy

    redirect_to band_music_path(@band, @music), notice: t("flash.music_versions.deleted")
  end

  def make_primary
    set_user_default(@version)

    redirect_to band_music_path(@band, @music), notice: t("flash.music_versions.default_updated")
  end

  private

  def set_band
    @band = Band.find(params[:band_id])
  end

  def require_membership
    redirect_to bands_path, alert: t("flash.shared.access_denied") unless Current.user.member_of?(@band)
  end

  def set_music
    @music = @band.musics.find(params[:music_id])
  end

  def set_version
    @version = @music.versions.find(params[:id])
  end

  def version_params
    params.expect(music_version: [ :name, :lyrics, :chords ])
  end

  def default_for_current_user?
    params.dig(:music_version, :default_for_me) == "1"
  end

  def set_user_default(version)
    Current.user.music_version_preferences
      .find_or_initialize_by(music: @music)
      .update!(music_version: version)
  end
end
