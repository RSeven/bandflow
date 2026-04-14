class MusicsController < ApplicationController
  before_action :set_band
  before_action :require_membership
  before_action :set_music, only: [ :show, :edit, :update, :destroy ]

  def show; end

  def new
    @music = @band.musics.new
  end

  def create
    @music = @band.musics.new(music_params)
    if @music.save
      flash[:notice] = t("flash.musics.created")
      flash[:new_music_link] = new_band_music_path(@band)
      redirect_to band_music_path(@band, @music)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @music.update(music_params)
      redirect_to band_music_path(@band, @music), notice: t("flash.musics.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @music.destroy
    redirect_to @band, notice: t("flash.musics.deleted")
  end

  # GET /bands/:band_id/musics/search?q=...  (iTunes autocomplete)
  def search
    q = params[:q].to_s.strip
    results = q.length >= 2 ? ItunesSearchService.search(q, limit: 8) : []
    render json: results.map { |r|
      { track_name: r.track_name, artist_name: r.artist_name, artwork_url: r.artwork_url }
    }
  end

  # POST /bands/:band_id/musics/fetch_metadata
  # Parameters: title, artist, source (one of MusicMetadataService::SOURCES)
  def fetch_metadata
    title  = params[:title].to_s.strip
    artist = params[:artist].to_s.strip
    source = params[:source].to_s

    if title.blank? || artist.blank?
      render json: { error: t("flash.musics.title_and_artist_required") }, status: :unprocessable_entity
      return
    end

    unless MusicMetadataService::SOURCES.include?(source)
      render json: { error: t("flash.musics.unknown_source") }, status: :unprocessable_entity
      return
    end

    render json: MusicMetadataService.fetch(source: source, title: title, artist: artist)
  end

  private

  def set_band
    @band = Band.find(params[:band_id])
  end

  def require_membership
    redirect_to bands_path, alert: t("flash.shared.access_denied") unless Current.user.member_of?(@band)
  end

  def set_music
    @music = @band.musics.find(params[:id])
  end

  def music_params
    params.expect(music: [
      :title, :artist, :lyrics, :chords,
      :spotify_url, :youtube_url, :spotify_track_id,
      :bpm, :key_name, :key_mode
    ])
  end
end
