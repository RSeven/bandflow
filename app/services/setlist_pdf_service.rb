require "prawn"

Prawn::Fonts::AFM.hide_m17n_warning = true

# Renders a setlist as a single-page A4 PDF listing all music items.
# Font size is computed from the item count so the list always fits.
class SetlistPdfService
  PAGE_SIZE       = "A4".freeze
  PAGE_MARGIN     = 40
  HEADER_HEIGHT   = 90
  MIN_FONT_SIZE   = 8
  MAX_FONT_SIZE   = 20
  LINE_SPACING    = 1.35

  def self.render(setlist)
    new(setlist).render
  end

  def initialize(setlist)
    @setlist = setlist
    @musics  = setlist.music_items.map(&:item)
  end

  def render
    Prawn::Document.new(
      page_size: PAGE_SIZE,
      margin:    PAGE_MARGIN,
      info:      { Title: @setlist.title, Creator: "BandFlow" }
    ).tap { |pdf| draw(pdf) }.render
  end

  private

  def draw(pdf)
    draw_header(pdf)
    draw_items(pdf)
  end

  def draw_header(pdf)
    pdf.font("Helvetica") do
      pdf.text @setlist.band.name, size: 11, color: "888888"
      pdf.move_down 4
      pdf.text @setlist.title, size: 22, style: :bold

      subtitle = header_subtitle
      if subtitle.present?
        pdf.move_down 4
        pdf.text subtitle, size: 11, color: "555555"
      end
    end

    pdf.move_down 14
    pdf.stroke_color "cccccc"
    pdf.stroke_horizontal_rule
    pdf.move_down 14
  end

  def header_subtitle
    parts = []
    parts << @setlist.performance_date.strftime("%B %-d, %Y") if @setlist.performance_date.present?
    parts << "#{@musics.size} songs"
    parts.join("  •  ")
  end

  def draw_items(pdf)
    if @musics.empty?
      pdf.text "(no songs in this setlist)", size: 12, color: "888888", style: :italic
      return
    end

    font_size   = compute_font_size(pdf)
    line_height = font_size * LINE_SPACING
    index_width = pdf.width_of("#{@musics.size}.", size: font_size, style: :bold) + 8

    pdf.font("Helvetica") do
      @musics.each_with_index do |music, i|
        y = pdf.cursor
        pdf.draw_text "#{i + 1}.",
          at:    [ 0, y - font_size ],
          size:  font_size,
          style: :bold
        pdf.draw_text music.title.to_s,
          at:   [ index_width, y - font_size ],
          size: font_size
        if music.artist.present?
          artist_text = "— #{music.artist}"
          title_width = pdf.width_of(music.title.to_s, size: font_size)
          pdf.draw_text artist_text,
            at:    [ index_width + title_width + 6, y - font_size ],
            size:  font_size * 0.85,
            color: "888888"
        end
        pdf.move_down line_height
      end
    end
  end

  # Largest font size (clamped between MIN and MAX) for which every item fits
  # in the remaining body area of one page.
  def compute_font_size(pdf)
    available = pdf.cursor - PAGE_MARGIN
    raw       = available / (@musics.size * LINE_SPACING)
    [ [ raw.floor, MAX_FONT_SIZE ].min, MIN_FONT_SIZE ].max
  end
end
