class LocalesController < ApplicationController
  skip_before_action :require_authentication

  def update
    locale = params[:locale].to_s
    session[:locale] = locale if app_locales.map(&:to_s).include?(locale)

    redirect_to safe_redirect_path
  end

  private

  def app_locales
    Rails.application.config.i18n.available_locales
  end

  def safe_redirect_path
    path = params[:redirect_path].to_s
    return root_path if path.blank? || !path.start_with?("/")

    path
  end
end
