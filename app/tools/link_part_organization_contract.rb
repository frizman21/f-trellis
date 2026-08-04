# The contract for `link_part_organization`, shared by the writing tool and the
# recording stand-in an evaluation runs instead. See UpsertOrganizationContract
# for why this is a module rather than a superclass.
module LinkPartOrganizationContract
  TOOL_NAME = "link_part_organization"

  def self.included(base)
    base.description <<~DESC
      Link a Part to the Organization behind it with a named relationship type
      (e.g. "Manufacturer", "Consumer", "Demand"). Creates the PartOrganization
      edge if one doesn't already exist, then inserts a new
      PartOrganizationDetail attached to the active SourceProcessingReport,
      attaches the named PartOrganizationType, and updates the edge's current
      detail pointer. Use after upsert_part and upsert_organization.
    DESC

    base.param :part_id, type: "integer", desc: "Part.id from upsert_part."
    base.param :organization_id, type: "integer", desc: "Organization.id from upsert_organization."
    base.param :type, type: "string",
               desc: "Name of the PartOrganizationType to attach (e.g. 'Manufacturer'). Must already exist."
    base.param :as_of, type: "string",
               desc: "ISO 8601 datetime the relationship was effective. Defaults to now.",
               required: false
    base.param :confidence_tenths, type: "integer",
               desc: "Confidence 0–1000 (1000 = 100%). Defaults to 800.",
               required: false
    base.param :additional_attributes, type: "object",
               desc: "Flat map of string keys to scalar values (e.g. model_year, program, quantity).",
               required: false
  end

  def name = TOOL_NAME
end
