class RehearsalsController < ApplicationController
  before_action :set_band
  before_action :require_membership
  before_action :set_music, only: %i[ show update ]

  def index
    @query = params[:q].to_s.strip
    @sort = sort_param
    @musics = rehearsal_scope
  end

  def show
    render layout: "presentation"
  end

  def update
    @music.update!(last_rehearsed_at: rehearsal_time)

    redirect_to redirect_after_update, notice: t("flash.rehearsals.updated", title: @music.title)
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

  def rehearsal_scope
    scope = @band.musics
    if @query.present?
      escaped_query = ActiveRecord::Base.sanitize_sql_like(@query)
      scope = scope.where("title LIKE :query OR artist LIKE :query", query: "%#{escaped_query}%")
    end

    case @sort
    when "newest"
      scope.order(Arel.sql("last_rehearsed_at IS NULL ASC, last_rehearsed_at DESC, title ASC"))
    else
      scope.order(Arel.sql("last_rehearsed_at IS NULL DESC, last_rehearsed_at ASC, title ASC"))
    end
  end

  def sort_param
    %w[oldest newest].include?(params[:sort]) ? params[:sort] : "oldest"
  end

  def rehearsal_time
    return Date.current if params[:mark_now].present?
    return nil if params[:last_rehearsed_at].blank?

    Date.parse(params[:last_rehearsed_at])
  end

  def redirect_after_update
    if params[:return_to] == "show"
      band_rehearsal_music_path(@band, @music)
    else
      band_rehearsal_path(@band, q: params[:q], sort: params[:sort])
    end
  end
end
