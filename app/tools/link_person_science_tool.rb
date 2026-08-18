class LinkPersonScienceTool < RubyLLM::Tool
  include LinkPersonScienceContract

  def initialize(report)
    super()
    @report = report
  end

  def execute(person_id:, science_id:, type:, as_of: nil, confidence_tenths: 800, additional_attributes: {})
    person = Person.find_by(id: person_id)
    return { error: "no person ##{person_id}" } unless person

    science = Science.find_by(id: science_id)
    return { error: "no science ##{science_id}" } unless science

    type_name = type.to_s.strip
    return { error: "type is required" } if type_name.empty?

    relationship_type = PersonScienceType.find_by(name: type_name)
    return { error: "PersonScienceType '#{type_name}' is not configured" } unless relationship_type

    edge = PersonScience.find_or_create_by!(person: person, science: science)

    detail = PersonScienceDetail.create!(
      person_science: edge,
      source_processing_report: @report,
      as_of: parse_as_of(as_of),
      confidence_tenths: clamp_confidence(confidence_tenths),
      additional_attributes: sanitize_attrs(additional_attributes)
    )

    detail.person_science_types = [ relationship_type ]
    edge.update!(current_detail: detail)

    {
      person_science_id: edge.id,
      detail_id: detail.id,
      person_id: person.id,
      science_id: science.id,
      type: relationship_type.name
    }
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end

  private

  def parse_as_of(value)
    return Time.current if value.blank?

    Time.zone.parse(value.to_s) || Time.current
  rescue ArgumentError
    Time.current
  end

  def clamp_confidence(value)
    [ [ value.to_i, 0 ].max, 1000 ].min
  end

  def sanitize_attrs(attrs)
    return {} unless attrs.is_a?(Hash)

    attrs.each_with_object({}) do |(k, v), out|
      next unless v.is_a?(String) || v.is_a?(Numeric) || v == true || v == false
      out[k.to_s] = v
    end
  end
end
