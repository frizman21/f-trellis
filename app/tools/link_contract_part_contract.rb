# The contract for `link_contract_part`, shared by the writing tool and the recording
# stand-in an evaluation runs instead. See UpsertOrganizationContract for why
# this is a module rather than a superclass.
module LinkContractPartContract
  TOOL_NAME = "link_contract_part"

  def self.included(base)
    base.description <<~DESC
      Link a Contract to a Part it delivers or procures\n      (e.g. "Deliverable", "Component", "Procurement").
      Creates the ContractPart edge if one doesn't already exist, then inserts a new
      ContractPartDetail attached to the active SourceProcessingReport, attaches the
      named ContractPartType, and updates the edge's current detail pointer. Use after
      upsert_contract and upsert_part.
    DESC

    base.param :contract_id, type: "integer", desc: "Contract.id from upsert_contract."
    base.param :part_id, type: "integer", desc: "Part.id from upsert_part."
    base.param :type, type: "string",
               desc: "Name of the ContractPartType to attach (e.g. 'Deliverable'). Must already exist."
    base.param :as_of, type: "string",
               desc: "ISO 8601 datetime the relationship was effective. Defaults to now.",
               required: false
    base.param :confidence_tenths, type: "integer",
               desc: "Confidence 0–1000 (1000 = 100%). Defaults to 800. Lower it where the link " \
                     "is your inference rather than something the source states.",
               required: false
    base.param :additional_attributes, type: "object",
               desc: "Flat map of string keys to scalar values (e.g. quantity, since).",
               required: false
  end

  def name = TOOL_NAME
end
