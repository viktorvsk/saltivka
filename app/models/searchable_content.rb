class SearchableContent < ApplicationRecord
  self.primary_key = :event_id
  DEFAULT_LANGUAGE = RELAY_CONFIG.ts_default_language
  AVAILABLE_LANGUAGES = %w[
    simple
    arabic
    armenian
    basque
    catalan
    danish
    dutch
    english
    finnish
    french
    german
    greek
    hindi
    hungarian
    indonesian
    irish
    italian
    lithuanian
    nepali
    norwegian
    portuguese
    romanian
    serbian
    spanish
    swedish
    tamil
    turkish
    yiddish
  ]
  belongs_to :event
  validates :event_id, uniqueness: true
  validates :language, :tsv_content, presence: true
  validates :language, inclusion: {in: AVAILABLE_LANGUAGES}

  def tsv_content=(text_content)
    text_content = case event.kind
    when 0
      rows = []
      begin
        JSON.parse(text_content).each { |k, v| rows.push("#{k} #{v}") }
      rescue
        nil
      end
      rows.push("__EMPTY__") if rows.empty?
      rows.join("\n")
    else
      text_content
    end

    sanitized_text = ActiveRecord::Base.sanitize_sql_array(["?", text_content.delete("\x00")])

    tsv = self.class.find_by_sql(["SELECT to_tsvector('#{language}', ?) AS tsv", sanitized_text]).first.tsv

    super(tsv)
  end

  def language=(value)
    super(value)

    self.tsv_content = event.content if persisted? && language != value
  end
end
