class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  around_action :switch_locale

  private

  def switch_locale(&action)
    locale = params[:locale].presence || session[:locale].presence
    locale = I18n.default_locale unless app_locales.map(&:to_s).include?(locale.to_s)

    I18n.with_locale(locale, &action)
  end

  def app_locales
    Rails.application.config.i18n.available_locales
  end
end
