# The contract for `link_contract_organization`, shared by the writing tool and the recording
# stand-in an evaluation runs instead. See UpsertOrganizationContract for why
# this is a module rather than a superclass.
module LinkContractOrganizationContract
  TOOL_NAME = "link_contract_organization"

  def self.included(base)
    base.description <<~DESC
      Link a Contract to an Organization that holds, funds or works under it\n      (e.g. "Awardee", "Awarding Agency", "Subcontractor", "Research Institution").
      Creates the ContractOrganization edge if one doesn't already exist, then inserts a new
      ContractOrganizationDetail attached to the active SourceProcessingReport, attaches the
      named ContractOrganizationType, and updates the edge's current detail pointer. Use after
      upsert_contract and upsert_organization.
    DESC

    base.param :contract_id, type: "integer", desc: "Contract.id from upsert_contract."
    base.param :organization_id, type: "integer", desc: "Organization.id from upsert_organization."
    base.param :type, type: "string",
               desc: "Name of the ContractOrganizationType to attach (e.g. 'Awardee'). Must already exist."
    base.param :as_of, type: "string",
               desc: "ISO 8601 datetime the relationship was effective. Defaults to now.",
               required: false
    base.param :confidence_tenths, type: "integer",
               desc: "Confidence 0–1000 (1000 = 100%). Defaults to 800. Lower it where the link " \
                     "is your inference rather than something the source states.",
               required: false
    base.param :additional_attributes, type: "object",
               desc: "Flat map of string keys to scalar values (e.g. role, since).",
               required: false
  end

  def name = TOOL_NAME
end
