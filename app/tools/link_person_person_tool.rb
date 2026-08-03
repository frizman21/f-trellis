class LinkPersonPersonTool < RubyLLM::Tool
  include LinkPersonPersonContract

  def initialize(report)
    super()
    @report = report
  end

  def execute(person_a_id:, person_b_id:, type:, as_of: nil, confidence_tenths: 800, additional_attributes: {})
    return { error: "person_a_id and person_b_id must be different" } if person_a_id == person_b_id

    person_a = Person.find_by(id: person_a_id)
    return { error: "no person ##{person_a_id}" } unless person_a

    person_b = Person.find_by(id: person_b_id)
    return { error: "no person ##{person_b_id}" } unless person_b

    type_name = type.to_s.strip
    return { error: "type is required" } if type_name.empty?

    relationship_type = PersonPersonType.find_by(name: type_name)
    return { error: "PersonPersonType '#{type_name}' is not configured" } unless relationship_type

    # Keyed on the unordered pair, so a page naming the two in one order and a
    # page naming them in the other land on one edge rather than two.
    sorted_a, sorted_b = [ person_a.id, person_b.id ].sort
    edge = PersonPerson.find_or_create_by!(person_a_id: sorted_a, person_b_id: sorted_b)

    detail = PersonPersonDetail.create!(
      person_person: edge,
      source_processing_report: @report,
      as_of: parse_as_of(as_of),
      confidence_tenths: clamp_confidence(confidence_tenths),
      additional_attributes: sanitize_attrs(additional_attributes)
    )

    detail.person_person_types = [ relationship_type ]
    edge.update!(current_detail: detail)

    {
      person_person_id: edge.id,
      detail_id: detail.id,
      person_a_id: edge.person_a_id,
      person_b_id: edge.person_b_id,
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
