class BandsController < ApplicationController
  before_action :set_band, only: [ :show, :edit, :update, :destroy ]
  before_action :require_membership, only: [ :show ]
  before_action :require_admin, only: [ :edit, :update, :destroy ]

  def index
    @bands = Current.user.bands.includes(:band_memberships)
  end

  def show
    @musics   = @band.musics.order(:title)
    @setlists = @band.setlists.order(performance_date: :desc, created_at: :desc)
  end

  def new
    @band = Band.new
  end

  def create
    @band = Band.new(band_params)
    if @band.save
      @band.band_memberships.create!(user: Current.user, role: "admin")
      redirect_to @band, notice: "Band created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @band.update(band_params)
      redirect_to @band, notice: "Band updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @band.destroy
    redirect_to bands_path, notice: "Band deleted."
  end

  private

  def set_band
    @band = Band.find(params[:id])
  end

  def require_membership
    redirect_to bands_path, alert: "You are not a member of this band." unless Current.user.member_of?(@band)
  end

  def require_admin
    redirect_to @band, alert: "Only admins can do that." unless Current.user.admin_of?(@band)
  end

  def band_params
    params.expect(band: [ :name, :description ])
  end
end
