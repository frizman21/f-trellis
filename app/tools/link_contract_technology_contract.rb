# The contract for `link_contract_technology`, shared by the writing tool and the recording
# stand-in an evaluation runs instead. See UpsertOrganizationContract for why
# this is a module rather than a superclass.
module LinkContractTechnologyContract
  TOOL_NAME = "link_contract_technology"

  def self.included(base)
    base.description <<~DESC
      Link a Contract to the Technology it funds work on\n      (e.g. "Develop", "Apply", "Evaluate", "Mature"). This is the edge that says\n      what a contract is actually for.
      Creates the ContractTechnology edge if one doesn't already exist, then inserts a new
      ContractTechnologyDetail attached to the active SourceProcessingReport, attaches the
      named ContractTechnologyType, and updates the edge's current detail pointer. Use after
      upsert_contract and upsert_technology.
    DESC

    base.param :contract_id, type: "integer", desc: "Contract.id from upsert_contract."
    base.param :technology_id, type: "integer", desc: "Technology.id from upsert_technology."
    base.param :type, type: "string",
               desc: "Name of the ContractTechnologyType to attach (e.g. 'Develop'). Must already exist."
    base.param :as_of, type: "string",
               desc: "ISO 8601 datetime the relationship was effective. Defaults to now.",
               required: false
    base.param :confidence_tenths, type: "integer",
               desc: "Confidence 0–1000 (1000 = 100%). Defaults to 800. Lower it where the link " \
                     "is your inference rather than something the source states.",
               required: false
    base.param :additional_attributes, type: "object",
               desc: "Flat map of string keys to scalar values (e.g. phase, since).",
               required: false
  end

  def name = TOOL_NAME
end
