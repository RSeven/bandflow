class SetlistItemsController < ApplicationController
  SIDEBAR_PAGE_SIZE = SetlistsController::SIDEBAR_PAGE_SIZE

  before_action :set_band
  before_action :require_membership
  before_action :set_setlist

  def create
    item_class = params[:item_type].to_s.classify
    item_class = %w[Music Event].include?(item_class) ? item_class.constantize : nil

    unless item_class
      redirect_to band_setlist_path(@band, @setlist), alert: t("flash.setlist_items.invalid_type")
      return
    end

    item = item_class == Music ? @band.musics.find(params[:item_id]) : @band.events.find(params[:item_id])
    @item = @setlist.setlist_items.create!(item: item)
    load_sidebar_collections

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to band_setlist_path(@band, @setlist) }
    end
  end

  def destroy
    @setlist_item = @setlist.setlist_items.find(params[:id])
    @setlist_item.destroy
    load_sidebar_collections

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to band_setlist_path(@band, @setlist) }
    end
  end

  def update
    @setlist_item = @setlist.setlist_items.find(params[:id])
    # Used for drag-and-drop reordering
    if params[:position].present?
      reorder(params[:position].to_i)
    end
    head :ok
  end

  private

  def set_band
    @band = Band.find(params[:band_id])
  end

  def require_membership
    redirect_to bands_path, alert: t("flash.shared.access_denied") unless Current.user.member_of?(@band)
  end

  def set_setlist
    @setlist = @band.setlists.find(params[:setlist_id])
  end

  def reorder(new_position)
    old_position = @setlist_item.position
    items = @setlist.setlist_items.order(:position).to_a
    items.delete(@setlist_item)
    items.insert(new_position, @setlist_item)
    items.each_with_index do |item, idx|
      item.update_column(:position, idx)
    end
  end

  def load_sidebar_collections
    @setlist_items = @setlist.ordered_items
    @music_query = params[:music_query].to_s.strip
    @event_query = params[:event_query].to_s.strip
    @music_page = page_param(:music_page)
    @event_page = page_param(:event_page)

    musics_scope = @band.musics
      .where.not(id: @setlist.setlist_items.where(item_type: "Music").select(:item_id))
      .order(:title)
    if @music_query.present?
      escaped_query = ActiveRecord::Base.sanitize_sql_like(@music_query)
      musics_scope = musics_scope.where("title LIKE :query OR artist LIKE :query", query: "%#{escaped_query}%")
    end

    events_scope = @band.events.order(:title)
    if @event_query.present?
      escaped_query = ActiveRecord::Base.sanitize_sql_like(@event_query)
      events_scope = events_scope.where("title LIKE :query OR description LIKE :query", query: "%#{escaped_query}%")
    end

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
    [(scope.count.to_f / SIDEBAR_PAGE_SIZE).ceil, 1].max
  end
end
