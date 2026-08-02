# The contract for `link_person_organization`, shared by the writing tool and the
# recording stand-in an evaluation runs instead. See UpsertOrganizationContract
# for why this is a module rather than a superclass.
module LinkPersonOrganizationContract
  TOOL_NAME = "link_person_organization"

  def self.included(base)
    base.description <<~DESC
      Link a Person to an Organization with a named relationship type (e.g.
      "Employment", "Affiliation"). Creates the PersonOrganization edge if one
      doesn't already exist, then inserts a new PersonOrganizationDetail
      attached to the active SourceProcessingReport, attaches the named
      PersonOrganizationType, and updates the edge's current detail pointer.
      Use after upsert_person and upsert_organization.
    DESC

    base.param :person_id, type: "integer", desc: "Person.id from upsert_person."
    base.param :organization_id, type: "integer", desc: "Organization.id from upsert_organization."
    base.param :type, type: "string",
               desc: "Name of the PersonOrganizationType to attach (e.g. 'Employment'). Must already exist."
    base.param :as_of, type: "string",
               desc: "ISO 8601 datetime the relationship was effective. Defaults to now.",
               required: false
    base.param :confidence_tenths, type: "integer",
               desc: "Confidence 0–1000 (1000 = 100%). Defaults to 800.",
               required: false
    base.param :additional_attributes, type: "object",
               desc: "Flat map of string keys to scalar values (e.g. role, title, department, start_date, end_date).",
               required: false
  end

  def name = TOOL_NAME
end
