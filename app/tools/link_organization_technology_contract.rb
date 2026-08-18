# The contract for `link_organization_technology`, shared by the writing tool and the recording
# stand-in an evaluation runs instead. See UpsertOrganizationContract for why
# this is a module rather than a superclass.
module LinkOrganizationTechnologyContract
  TOOL_NAME = "link_organization_technology"

  def self.included(base)
    base.description <<~DESC
      Link an Organization directly to a Technology it develops, funds, adopts or\n      licenses. Use this where no contract is named — a company doing internal\n      R&D, an adopter, a licensee. Where the source does name a contract, prefer\n      link_contract_organization and link_contract_technology, which say the same\n      thing with the funded work in between.
      Creates the OrganizationTechnology edge if one doesn't already exist, then inserts a new
      OrganizationTechnologyDetail attached to the active SourceProcessingReport, attaches the
      named OrganizationTechnologyType, and updates the edge's current detail pointer. Use after
      upsert_organization and upsert_technology.
    DESC

    base.param :organization_id, type: "integer", desc: "Organization.id from upsert_organization."
    base.param :technology_id, type: "integer", desc: "Technology.id from upsert_technology."
    base.param :type, type: "string",
               desc: "Name of the OrganizationTechnologyType to attach (e.g. 'Developer'). Must already exist."
    base.param :as_of, type: "string",
               desc: "ISO 8601 datetime the relationship was effective. Defaults to now.",
               required: false
    base.param :confidence_tenths, type: "integer",
               desc: "Confidence 0–1000 (1000 = 100%). Defaults to 800. Lower it where the link " \
                     "is your inference rather than something the source states.",
               required: false
    base.param :additional_attributes, type: "object",
               desc: "Flat map of string keys to scalar values (e.g. since, maturity).",
               required: false
  end

  def name = TOOL_NAME
end
