class EventsController < ApplicationController
  before_action :set_band
  before_action :require_membership
  before_action :set_event, only: [ :edit, :update, :destroy ]

  def new
    @event = @band.events.new
  end

  def create
    @event = @band.events.new(event_params)
    if @event.save
      redirect_to @band, notice: t("flash.events.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @event.update(event_params)
      redirect_to @band, notice: t("flash.events.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    redirect_to @band, notice: t("flash.events.deleted")
  end

  private

  def set_band
    @band = Band.find(params[:band_id])
  end

  def require_membership
    redirect_to bands_path, alert: t("flash.shared.access_denied") unless Current.user.member_of?(@band)
  end

  def set_event
    @event = @band.events.find(params[:id])
  end

  def event_params
    params.expect(event: [ :title, :description ])
  end
end
