# `upsert_part` as an evaluation runs it: identical contract, no rows written.
# See RecordingUpsertPersonTool for why the stand-ins exist.
#
# The part type and parameter lookups are reads, so they write nothing — and
# reproducing them matters more here than anywhere else, because the taxonomy is
# most of what this tool enforces. A stand-in that accepted any parameter name
# would score a model for specifications the real run would have thrown away.
class RecordingUpsertPartTool < RubyLLM::Tool
  include UpsertPartContract

  def initialize(recorder)
    super()
    @recorder = recorder
  end

  def execute(parts:)
    entries = Array(parts)
    return { error: "parts must be a non-empty array" } if entries.empty?

    { results: entries.map { |entry| record_one(entry) } }
  end

  private

  def record_one(entry)
    attrs = EntityUpsert::Entry.new(entry)
    canonical = attrs.string(:name)
    return { error: "name is required" } if canonical.empty?

    types, unknown = resolve_types(attrs.value(:part_types))
    if types.empty?
      return { error: "no part type matched #{unknown.to_sentence.presence || 'an empty list'}; " \
                      "valid types are #{PartType.order(:name).pluck(:name).to_sentence}" }
    end

    specifications, rejected = accepted_specifications(types, attrs.value(:specifications))

    part_id, created = @recorder.record_part(
      name: canonical,
      part_types: types.map(&:name),
      specifications: specifications,
      attributes: attrs.value(:additional_attributes)
    )

    {
      part_id: part_id, detail_id: @recorder.next_detail_id, created: created,
      specifications_recorded: specifications.size,
      specification_errors: rejected + unknown.map { |name| "part type '#{name}' is not configured" }
    }
  end

  def resolve_types(names)
    known = PartType.order(:name).to_a
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

  # The same acceptance rules the writing tool applies, minus the row it would
  # have built: only declared parameters, only in the declared unit, only with a
  # value that parses.
  def accepted_specifications(types, specifications)
    declared = PartTypeParameter.where(part_type_id: types.map(&:id)).ordered.to_a
    accepted = []
    rejected = []

    Array(specifications).each do |raw|
      spec = EntityUpsert::Entry.new(raw)
      name = spec.string(:parameter)
      parameter = declared.find { |p| p.name.casecmp?(name) }

      if parameter.nil?
        rejected << "'#{name}' is not a parameter of #{types.map(&:name).to_sentence}"
        next
      end

      stated_unit = spec.string(:unit).presence
      if parameter.number? && stated_unit && !stated_unit.casecmp?(parameter.unit.to_s)
        rejected << "#{parameter.name} was given in #{stated_unit}, but is recorded in #{parameter.unit} — convert it"
        next
      end

      value = spec.string(:value)
      if value.empty?
        rejected << "#{parameter.name} has no value"
        next
      end

      if parameter.number? && !value.match?(/-?\d/)
        rejected << "#{parameter.name} needs a number, not '#{value}'"
        next
      end

      accepted << { "parameter" => parameter.name, "unit" => parameter.unit, "value" => value }
    end

    [ accepted, rejected ]
  end
end
