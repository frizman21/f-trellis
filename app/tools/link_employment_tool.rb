class LinkEmploymentTool < RubyLLM::Tool
  description <<~DESC
    Link a Person to an Organization with the "Employment" relationship type.
    Creates the PersonOrganization edge if one doesn't already exist, then
    inserts a new PersonOrganizationDetail attached to the active
    SourceProcessingReport, attaches the "Employment" type, and updates the
    edge's current detail pointer. Use after upsert_person and
    upsert_organization to record that the person worked at the organization.
  DESC

  param :person_id, type: "integer", desc: "Person.id from upsert_person."
  param :organization_id, type: "integer", desc: "Organization.id from upsert_organization."
  param :as_of, type: "string",
        desc: "ISO 8601 datetime the employment was effective. Defaults to now.",
        required: false
  param :confidence_tenths, type: "integer",
        desc: "Confidence 0–1000 (1000 = 100%). Defaults to 800.",
        required: false
  param :additional_attributes, type: "object",
        desc: "Flat map of string keys to scalar values (e.g. role, title, department).",
        required: false

  EMPLOYMENT_TYPE_NAME = "Employment".freeze

  def initialize(report)
    super()
    @report = report
  end

  def execute(person_id:, organization_id:, as_of: nil, confidence_tenths: 800, additional_attributes: {})
    person = Person.find_by(id: person_id)
    return { error: "no person ##{person_id}" } unless person

    organization = Organization.find_by(id: organization_id)
    return { error: "no organization ##{organization_id}" } unless organization

    employment_type = PersonOrganizationType.find_by(name: EMPLOYMENT_TYPE_NAME)
    return { error: "PersonOrganizationType '#{EMPLOYMENT_TYPE_NAME}' is not configured" } unless employment_type

    po = PersonOrganization.find_or_create_by!(person: person, organization: organization)

    detail = PersonOrganizationDetail.create!(
      person_organization: po,
      source_processing_report: @report,
      as_of: parse_as_of(as_of),
      confidence_tenths: clamp_confidence(confidence_tenths),
      additional_attributes: sanitize_attrs(additional_attributes)
    )

    detail.person_organization_types = [ employment_type ]
    po.update!(current_detail: detail)

    {
      person_organization_id: po.id,
      detail_id: detail.id,
      person_id: person.id,
      organization_id: organization.id
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
