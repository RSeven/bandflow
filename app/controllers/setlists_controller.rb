class SetlistsController < ApplicationController
  before_action :set_band
  before_action :require_membership
  before_action :set_setlist, only: [ :show, :edit, :update, :destroy, :present ]

  def show
    @setlist_items = @setlist.ordered_items
    @musics        = available_musics
    @events        = @band.events.order(:title)
  end

  def new
    @setlist = @band.setlists.new
  end

  def create
    @setlist = @band.setlists.new(setlist_params)
    if @setlist.save
      redirect_to band_setlist_path(@band, @setlist), notice: "Setlist created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @setlist.update(setlist_params)
      redirect_to band_setlist_path(@band, @setlist), notice: "Setlist updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @setlist.destroy
    redirect_to @band, notice: "Setlist deleted."
  end

  def present
    @setlist_items = @setlist.ordered_items
    render layout: "presentation"
  end

  private

  def set_band
    @band = Band.find(params[:band_id])
  end

  def require_membership
    redirect_to bands_path, alert: "Access denied." unless Current.user.member_of?(@band)
  end

  def set_setlist
    @setlist = @band.setlists.find(params[:id])
  end

  def setlist_params
    params.expect(setlist: [ :title, :performance_date, :notes ])
  end

  def available_musics
    @band.musics
      .where.not(id: @setlist.setlist_items.where(item_type: "Music").select(:item_id))
      .order(:title)
  end
end
