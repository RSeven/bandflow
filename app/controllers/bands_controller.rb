class BandsController < ApplicationController
  PAGE_SIZE = 10

  before_action :set_band, only: [ :show, :edit, :update, :destroy ]
  before_action :require_membership, only: [ :show ]
  before_action :require_admin, only: [ :edit, :update, :destroy ]

  def index
    @bands = Current.user.bands.includes(:band_memberships)
  end

  def show
    @music_page = page_param(:music_page)
    @setlist_page = page_param(:setlist_page)
    @active_tab = active_tab_param
    @music_query = params[:music_query].to_s.strip

    musics_scope = @band.musics.order(:title)
    if @music_query.present?
      escaped_query = ActiveRecord::Base.sanitize_sql_like(@music_query)
      musics_scope = musics_scope.where("title LIKE :query OR artist LIKE :query", query: "%#{escaped_query}%")
    end
    setlists_scope = @band.setlists.order(performance_date: :desc, created_at: :desc)

    @musics_total_pages = total_pages_for(musics_scope)
    @setlists_total_pages = total_pages_for(setlists_scope)

    @musics = musics_scope.offset((@music_page - 1) * PAGE_SIZE).limit(PAGE_SIZE)
    @setlists = setlists_scope.offset((@setlist_page - 1) * PAGE_SIZE).limit(PAGE_SIZE)
  end

  def new
    @band = Band.new
  end

  def create
    @band = Band.new(band_params)
    if @band.save
      @band.band_memberships.create!(user: Current.user, role: "admin")
      redirect_to @band, notice: t("flash.bands.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @band.update(band_params)
      redirect_to @band, notice: t("flash.bands.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @band.destroy
    redirect_to bands_path, notice: t("flash.bands.deleted")
  end

  private

  def set_band
    @band = Band.find(params[:id])
  end

  def require_membership
    redirect_to bands_path, alert: t("flash.shared.not_band_member") unless Current.user.member_of?(@band)
  end

  def require_admin
    redirect_to @band, alert: t("flash.shared.admin_only") unless Current.user.admin_of?(@band)
  end

  def band_params
    params.expect(band: [ :name, :description ])
  end

  def page_param(key)
    value = params[key].to_i
    value.positive? ? value : 1
  end

  def total_pages_for(scope)
    [(scope.count.to_f / PAGE_SIZE).ceil, 1].max
  end

  def active_tab_param
    value = params[:tab].to_s
    %w[musics setlists].include?(value) ? value : "musics"
  end
end
