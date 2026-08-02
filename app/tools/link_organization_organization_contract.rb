# The contract for `link_organization_organization`, shared by the writing tool
# and the recording stand-in an evaluation runs instead. See
# UpsertOrganizationContract for why this is a module rather than a superclass.
module LinkOrganizationOrganizationContract
  TOOL_NAME = "link_organization_organization"

  def self.included(base)
    base.description <<~DESC
      Link two Organizations with a named relationship type (e.g. "Partnership",
      "Subsidiary"). Creates the OrganizationOrganization edge if one doesn't
      already exist (the edge is keyed on the unordered pair of organizations,
      so calling with the orgs in either order reuses the same edge), then
      inserts a new OrganizationOrganizationDetail attached to the active
      SourceProcessingReport, attaches the named OrganizationOrganizationType,
      and updates the edge's current detail pointer. Use after
      upsert_organization.

      For asymmetric relationship types where direction matters (e.g.
      "Subsidiary" — one org is the parent, the other is the subsidiary),
      encode the direction by including direction-coding keys in
      `additional_attributes` (for Subsidiary: `parent_organization_id` and
      `subsidiary_organization_id`).
    DESC

    base.param :organization_a_id, type: "integer",
               desc: "Organization.id of one side of the relationship from upsert_organization."
    base.param :organization_b_id, type: "integer",
               desc: "Organization.id of the other side from upsert_organization."
    base.param :type, type: "string",
               desc: "Name of the OrganizationOrganizationType to attach (e.g. 'Subsidiary', 'Partnership'). Must already exist."
    base.param :as_of, type: "string",
               desc: "ISO 8601 datetime the relationship was effective. Defaults to now.",
               required: false
    base.param :confidence_tenths, type: "integer",
               desc: "Confidence 0–1000 (1000 = 100%). Defaults to 800.",
               required: false
    base.param :additional_attributes, type: "object",
               desc: "Flat map of string keys to scalar values. For asymmetric types include direction-coding keys (e.g. parent_organization_id, subsidiary_organization_id).",
               required: false
  end

  def name = TOOL_NAME
end
