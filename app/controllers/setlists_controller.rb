class SetlistsController < ApplicationController
  SIDEBAR_PAGE_SIZE = 5

  before_action :set_band
  before_action :require_membership
  before_action :set_setlist, only: [ :show, :edit, :update, :destroy, :present, :export ]

  def show
    respond_to do |format|
      format.html do
        @setlist_items = @setlist.ordered_items
        load_sidebar_collections
      end
      format.pdf do
        pdf_data = SetlistPdfService.render(@setlist)
        send_data pdf_data,
          filename: "#{@setlist.title.parameterize}.pdf",
          type: "application/pdf",
          disposition: "inline"
      end
    end
  end

  def new
    @setlist = @band.setlists.new
  end

  def create
    @setlist = @band.setlists.new(setlist_params)
    if @setlist.save
      redirect_to band_setlist_path(@band, @setlist), notice: t("flash.setlists.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @setlist.update(setlist_params)
      redirect_to band_setlist_path(@band, @setlist), notice: t("flash.setlists.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @setlist.destroy
    redirect_to @band, notice: t("flash.setlists.deleted")
  end

  def present
    @setlist_items = @setlist.ordered_items
    render layout: "presentation"
  end

  def export
    @setlist_items = @setlist.ordered_items
    css = Rails.root.join("app/assets/builds/tailwind.css").read
    html = render_to_string(template: "setlists/export", layout: false, locals: { embedded_css: css })
    send_data html,
      filename: "#{@setlist.title.parameterize}-#{@band.name.parameterize}.html",
      type: "text/html",
      disposition: "attachment"
  end

  private

  def set_band
    @band = Band.find(params[:band_id])
  end

  def require_membership
    redirect_to bands_path, alert: t("flash.shared.access_denied") unless Current.user.member_of?(@band)
  end

  def set_setlist
    @setlist = @band.setlists.find(params[:id])
  end

  def setlist_params
    params.expect(setlist: [ :title, :performance_date, :notes ])
  end

  def available_musics
    scope = @band.musics
      .where.not(id: @setlist.setlist_items.where(item_type: "Music").select(:item_id))
      .order(:title)

    if @music_query.present?
      escaped_query = ActiveRecord::Base.sanitize_sql_like(@music_query)
      scope = scope.where("title LIKE :query OR artist LIKE :query", query: "%#{escaped_query}%")
    end

    scope
  end

  def available_events
    scope = @band.events.order(:title)

    if @event_query.present?
      escaped_query = ActiveRecord::Base.sanitize_sql_like(@event_query)
      scope = scope.where("title LIKE :query OR description LIKE :query", query: "%#{escaped_query}%")
    end

    scope
  end

  def load_sidebar_collections
    @music_query = params[:music_query].to_s.strip
    @event_query = params[:event_query].to_s.strip
    @music_page = page_param(:music_page)
    @event_page = page_param(:event_page)

    musics_scope = available_musics
    events_scope = available_events

    @musics_total_pages = total_pages_for(musics_scope)
    @events_total_pages = total_pages_for(events_scope)
    @music_page = [ @music_page, @musics_total_pages ].min
    @event_page = [ @event_page, @events_total_pages ].min

    @musics = musics_scope.offset((@music_page - 1) * SIDEBAR_PAGE_SIZE).limit(SIDEBAR_PAGE_SIZE)
    @events = events_scope.offset((@event_page - 1) * SIDEBAR_PAGE_SIZE).limit(SIDEBAR_PAGE_SIZE)
  end

  def page_param(key)
    value = params[key].to_i
    value.positive? ? value : 1
  end

  def total_pages_for(scope)
    [ (scope.count.to_f / SIDEBAR_PAGE_SIZE).ceil, 1 ].max
  end
end
