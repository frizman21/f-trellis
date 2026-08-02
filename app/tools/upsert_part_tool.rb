class UpsertPartTool < RubyLLM::Tool
  include EntityUpsert
  # Name, description and schema live in the contract, shared with the recording
  # stand-in an evaluation runs.
  include UpsertPartContract

  def initialize(report)
    super()
    @report = report
  end

  def execute(parts:)
    entries = Array(parts)
    return { error: "parts must be a non-empty array" } if entries.empty?

    { results: entries.map { |entry| upsert_one(entry) } }
  end

  private

  def upsert_one(entry)
    attrs = EntityUpsert::Entry.new(entry)
    canonical = attrs.string(:name)
    return { error: "name is required" } if canonical.empty?

    types, unknown = resolve_types(attrs.value(:part_types))
    if types.empty?
      return { error: "no part type matched #{unknown.to_sentence.presence || 'an empty list'}; " \
                      "valid types are #{PartType.order(:name).pluck(:name).to_sentence}" }
    end

    part, created = find_or_create_part(canonical)

    detail = PartDetail.create!(
      part: part,
      source_processing_report: @report,
      name: canonical,
      as_of: Time.current,
      confidence_tenths: clamp_confidence(attrs.value(:confidence_tenths)),
      additional_attributes: sanitize_attrs(attrs.value(:additional_attributes))
    )
    detail.part_types = types

    recorded, rejected = record_specifications(detail, types, attrs.value(:specifications))
    part.update!(current_detail: detail)

    {
      part_id: part.id, detail_id: detail.id, created: created,
      specifications_recorded: recorded, specification_errors: rejected + unknown_type_notes(unknown)
    }
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end

  # Names that matched a configured type, and the ones that did not. Reported
  # rather than silently dropped: a model naming a type that does not exist has
  # made a claim the taxonomy cannot hold, and it should hear about it.
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

  def unknown_type_notes(unknown)
    unknown.map { |name| "part type '#{name}' is not configured" }
  end

  # Values for the parameters the part's types declare. Anything else is left
  # out with a reason — the property bag is where an undeclared fact belongs, and
  # quietly inventing a parameter would make the taxonomy meaningless.
  def record_specifications(detail, types, specifications)
    declared = PartTypeParameter.where(part_type_id: types.map(&:id)).ordered.to_a
    recorded = 0
    rejected = []

    Array(specifications).each do |raw|
      spec = EntityUpsert::Entry.new(raw)
      name = spec.string(:parameter)
      parameter = declared.find { |p| p.name.casecmp?(name) }

      if parameter.nil?
        rejected << "'#{name}' is not a parameter of #{types.map(&:name).to_sentence}"
        next
      end

      error = record_one_specification(detail, parameter, spec)
      error ? rejected << error : recorded += 1
    end

    [ recorded, rejected ]
  end

  def record_one_specification(detail, parameter, spec)
    stated_unit = spec.string(:unit).presence
    if parameter.number? && stated_unit && !stated_unit.casecmp?(parameter.unit.to_s)
      return "#{parameter.name} was given in #{stated_unit}, but is recorded in #{parameter.unit} — convert it"
    end

    value = spec.string(:value)
    return "#{parameter.name} has no value" if value.empty?

    row = detail.part_detail_parameters.build(
      part_type_parameter: parameter,
      as_stated: spec.string(:as_stated).presence,
      confidence_tenths: clamp_confidence(spec.value(:confidence_tenths))
    )

    if parameter.number?
      number = parse_number(value)
      return "#{parameter.name} needs a number, not '#{value}'" if number.nil?

      row.value_number = number
    else
      row.value_text = value
    end

    row.save ? nil : "#{parameter.name}: #{row.errors.full_messages.to_sentence}"
  end

  # Tolerates what a page states around the digits — thousands separators, a
  # stray unit the model left on, a leading tilde. Refuses anything with no
  # number in it at all rather than storing a silent zero.
  def parse_number(value)
    cleaned = value.tr(",", "").strip
    match = cleaned.match(/-?\d+(?:\.\d+)?/)
    return nil if match.nil?

    BigDecimal(match[0])
  end

  def find_or_create_part(name)
    existing = Part.joins(:current_detail).where("LOWER(part_details.name) = ?", name.downcase).first

    return [ existing, false ] if existing

    [ Part.create!, true ]
  end
end
