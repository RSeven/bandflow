class MusicSearchQuery
  VIRTUAL_TAGS = %w[new].freeze

  def self.call(scope, query)
    new(scope, query).call
  end

  def initialize(scope, query)
    @scope = scope
    @query = query
  end

  def call
    relation = scope

    if parsed_query[:text].present?
      escaped_query = ActiveRecord::Base.sanitize_sql_like(parsed_query[:text])
      relation = relation.where(
        "LOWER(title) LIKE :query OR LOWER(artist) LIKE :query",
        query: "%#{escaped_query}%"
      )
    end

    parsed_query[:tag_prefixes].each do |tag_prefix|
      relation = with_tag_prefix(relation, tag_prefix)
    end

    relation
  end

  private

  attr_reader :scope, :query

  def parsed_query
    @parsed_query ||= begin
      tag_prefixes = []
      text_terms = []

      query.to_s.strip.split(/\s+/).each do |token|
        if token == "#"
          next
        elsif token.start_with?("#") && token.length > 1
          tag_prefixes << token.delete_prefix("#")
        else
          text_terms << token
        end
      end

      {
        text: text_terms.join(" ").downcase,
        tag_prefixes: tag_prefixes.map { |tag| normalize_tag(tag) }.reject(&:blank?)
      }
    end
  end

  def with_tag_prefix(relation, prefix)
    normalized_prefix = normalize_tag(prefix)
    return relation if normalized_prefix.blank?

    escaped_prefix = ActiveRecord::Base.sanitize_sql_like(normalized_prefix)
    clauses = [
      "labels LIKE :first_label_prefix",
      "labels LIKE :later_label_prefix"
    ]
    params = {
      first_label_prefix: "[\"#{escaped_prefix}%",
      later_label_prefix: "%,\"#{escaped_prefix}%"
    }

    if virtual_tag_keys_matching_prefix(normalized_prefix).include?("new")
      clauses << "created_at >= :new_threshold"
      params[:new_threshold] = Time.current - Music::NEW_WINDOW
    end

    relation.where(clauses.join(" OR "), params)
  end

  def virtual_tag_keys_matching_prefix(prefix)
    normalized_prefix = normalize_tag(prefix)

    VIRTUAL_TAGS.select do |key|
      [ key, I18n.t("musics.virtual_tags.#{key}", default: key) ]
        .map { |tag| normalize_tag(tag) }
        .any? { |tag| tag.start_with?(normalized_prefix) }
    end
  end

  def normalize_tag(value)
    value.to_s.squish.downcase.split(/[\s,]+/).first.to_s
  end
end
