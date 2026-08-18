# Matching type names a model gave against the taxonomy actually configured.
#
# Shared because four tools need the identical answer: the writing tool, its
# recording stand-in, and the same pair for the other entity. A stand-in that
# resolved types more loosely than the writing tool would credit a model for a
# type the real run would have dropped.
#
# Names that match nothing come back rather than being discarded silently — a
# model naming a type that does not exist has made a claim the taxonomy cannot
# hold, and it should hear about it.
module EntityTypeLookup
  private

  # [matched records, unmatched names]
  def resolve_types(type_class, names)
    known = type_class.order(:name).to_a
    matched = []
    unknown = []

    Array(names).each do |raw|
      name = raw.to_s.strip
      next if name.empty?

      type = known.find { |t| t.name.casecmp?(name) }
      type ? matched << type : unknown << name
    end

    [ matched.uniq, unknown ]
  end

  def unknown_type_notes(label, unknown)
    unknown.map { |name| "#{label} '#{name}' is not configured" }
  end

  def taxonomy_list(type_class)
    types = type_class.order(:name)
    return "  (none configured)" if types.empty?

    types.map { |t| "  - #{t.name}#{": #{t.description}" if t.description.present?}" }.join("\n")
  end
end
