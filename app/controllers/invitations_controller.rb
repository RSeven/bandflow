class InvitationsController < ApplicationController
  skip_before_action :require_authentication, only: [ :show, :accept ]

  before_action :set_band, only: [ :create, :destroy, :link ]
  before_action :require_membership, only: [ :create, :destroy, :link ]
  before_action :set_invitation_by_token, only: [ :show, :accept ]

  def create
    @invitation = @band.invitations.create!(invited_by: Current.user)
    redirect_to link_band_invitation_path(@band, @invitation), notice: t("flash.invitations.created")
  end

  def destroy
    @invitation = @band.invitations.find(params[:id])
    @invitation.destroy
    redirect_to @band, notice: t("flash.invitations.revoked")
  end

  def link
    @invitation = @band.invitations.find(params[:id])
    @invite_url = invitation_url(@invitation.token)
  end

  # Public — anyone with the link can view
  def show
    if @invitation.used?
      redirect_to root_path, alert: t("flash.invitations.used")
      return
    end

    if user_signed_in?
      # Logged-in user: show confirmation page
    else
      # Not logged in: redirect to sign up / log in with token stored in session
      session[:pending_invitation_token] = @invitation.token
      redirect_to new_registration_path, notice: t("flash.invitations.create_account", band: @invitation.band.name)
    end
  end

  # POST — accept the invitation
  def accept
    if @invitation.used?
      redirect_to root_path, alert: t("flash.invitations.used")
      return
    end

    unless user_signed_in?
      session[:pending_invitation_token] = @invitation.token
      redirect_to new_session_path, alert: t("flash.invitations.sign_in_first")
      return
    end

    band = @invitation.band
    if Current.user.member_of?(band)
      redirect_to band, notice: t("flash.invitations.already_member", band: band.name)
      return
    end

    band.band_memberships.create!(user: Current.user, role: "member")
    @invitation.mark_used!

    redirect_to band, notice: t("flash.invitations.welcome", band: band.name)
  end

  private

  def set_band
    @band = Band.find(params[:band_id])
  end

  def require_membership
    redirect_to bands_path, alert: t("flash.shared.access_denied") unless Current.user.member_of?(@band)
  end

  def set_invitation_by_token
    @invitation = Invitation.find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: t("flash.invitations.invalid_link")
  end

  def user_signed_in?
    resume_session
    Current.user.present?
  end
end
