class InvitationsController < ApplicationController
  skip_before_action :require_authentication, only: [ :show, :accept ]

  before_action :set_band, only: [ :create, :destroy, :link ]
  before_action :require_membership, only: [ :create, :destroy, :link ]
  before_action :set_invitation_by_token, only: [ :show, :accept ]

  def create
    @invitation = @band.invitations.create!(invited_by: Current.user)
    redirect_to link_band_invitation_path(@band, @invitation), notice: "Invitation created."
  end

  def destroy
    @invitation = @band.invitations.find(params[:id])
    @invitation.destroy
    redirect_to @band, notice: "Invitation revoked."
  end

  def link
    @invitation = @band.invitations.find(params[:id])
    @invite_url = invitation_url(@invitation.token)
  end

  # Public — anyone with the link can view
  def show
    if @invitation.used?
      redirect_to root_path, alert: "This invitation has already been used."
      return
    end

    if user_signed_in?
      # Logged-in user: show confirmation page
    else
      # Not logged in: redirect to sign up / log in with token stored in session
      session[:pending_invitation_token] = @invitation.token
      redirect_to new_registration_path, notice: "Create an account to join #{@invitation.band.name}."
    end
  end

  # POST — accept the invitation
  def accept
    if @invitation.used?
      redirect_to root_path, alert: "This invitation has already been used."
      return
    end

    unless user_signed_in?
      session[:pending_invitation_token] = @invitation.token
      redirect_to new_session_path, alert: "Please sign in first."
      return
    end

    band = @invitation.band
    if Current.user.member_of?(band)
      redirect_to band, notice: "You are already a member of #{band.name}."
      return
    end

    band.band_memberships.create!(user: Current.user, role: "member")
    @invitation.mark_used!

    redirect_to band, notice: "Welcome to #{band.name}!"
  end

  private

  def set_band
    @band = Band.find(params[:band_id])
  end

  def require_membership
    redirect_to bands_path, alert: "Access denied." unless Current.user.member_of?(@band)
  end

  def set_invitation_by_token
    @invitation = Invitation.find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Invalid invitation link."
  end

  def user_signed_in?
    resume_session
    Current.user.present?
  end
end
