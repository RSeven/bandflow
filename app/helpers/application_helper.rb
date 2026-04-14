module ApplicationHelper
  def pagination_params(param_name, page)
    request.query_parameters.merge(param_name => page)
  end

  def tab_params(tab_name)
    request.query_parameters.merge(tab: tab_name)
  end

  def locale_label(locale)
    t("locales.names.#{locale.to_s.tr('-', '_')}")
  end

  def locale_options
    app_locales.map { |locale| [ locale_label(locale), locale ] }
  end

  private

  def app_locales
    Rails.application.config.i18n.available_locales
  end
end
