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

  def safe_url(url)
    uri = URI.parse(url.to_s)
    uri.scheme.in?(%w[http https]) ? url : nil
  rescue URI::InvalidURIError
    nil
  end

  def music_label_badges(labels, compact: false)
    safe_join(labels.to_a.map { |label| music_label_badge(label, compact: compact) })
  end

  def music_display_label_badges(music, compact: false)
    labels = music.virtual_tag_keys.map { |key| t("musics.virtual_tags.#{key}") } + music.label_list
    music_label_badges(labels, compact: compact)
  end

  def music_label_badge(label, compact: false)
    tag.span(
      label,
      class: [
        "music-label-badge",
        ("music-label-badge--compact" if compact),
        music_label_badge_palette(label)
      ].join(" ")
    )
  end

  private

  def app_locales
    Rails.application.config.i18n.available_locales
  end

  def music_label_badge_palette(label)
    "music-label-badge--#{label.to_s.bytes.sum % 5}"
  end
end
