class SetlistItemsController < ApplicationController
  before_action :set_band
  before_action :require_membership
  before_action :set_setlist

  def create
    item_class = params[:item_type].to_s.classify
    item_class = %w[Music Event].include?(item_class) ? item_class.constantize : nil

    unless item_class
      redirect_to band_setlist_path(@band, @setlist), alert: "Invalid item type."
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
    redirect_to bands_path, alert: "Access denied." unless Current.user.member_of?(@band)
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
    @musics = @band.musics
      .where.not(id: @setlist.setlist_items.where(item_type: "Music").select(:item_id))
      .order(:title)
  end
end
