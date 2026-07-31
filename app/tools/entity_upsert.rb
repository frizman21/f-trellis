# Plumbing shared by the batched entity upsert tools. Both take an array of
# entries in one call rather than one entry per call: RubyLLM resends the whole
# conversation each turn, so N calls means the page is billed N+1 times.
module EntityUpsert
  DEFAULT_CONFIDENCE = 800
  MIN_CONFIDENCE = 0
  MAX_CONFIDENCE = 1000

  # Entries arrive as JSON, so keys may be strings or symbols depending on the
  # provider and on how the payload was parsed.
  class Entry
    def initialize(raw)
      @raw = raw.is_a?(Hash) ? raw : {}
    end

    def value(key)
      @raw[key].nil? ? @raw[key.to_s] : @raw[key]
    end

    def string(key)
      value(key).to_s.strip
    end
  end

  private

  def clamp_confidence(value)
    return DEFAULT_CONFIDENCE if value.nil?

    [ [ value.to_i, MIN_CONFIDENCE ].max, MAX_CONFIDENCE ].min
  end

  # Detail records take a flat map; drop anything a model nested or typed oddly.
  #
  # Accepts either a hash or the array-of-pairs shape the tool schema declares.
  # A free-form object cannot be expressed in a strict JSON schema — declaring
  # one compiles to `additionalProperties: false` with no properties, which the
  # model cannot put anything into — so the wire format is [{key:, value:}].
  def sanitize_attrs(attrs)
    pairs = case attrs
    when Hash  then attrs
    when Array then pairs_from_array(attrs)
    else return {}
    end

    pairs.each_with_object({}) do |(k, v), out|
      next if k.to_s.strip.empty?
      next unless v.is_a?(String) || v.is_a?(Numeric) || v == true || v == false
      out[k.to_s] = v
    end
  end

  def pairs_from_array(entries)
    entries.filter_map do |entry|
      next unless entry.is_a?(Hash)

      pair = Entry.new(entry)
      [ pair.string(:key), pair.value(:value) ]
    end
  end
end
