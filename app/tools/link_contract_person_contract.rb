# The contract for `link_contract_person`, shared by the writing tool and the recording
# stand-in an evaluation runs instead. See UpsertOrganizationContract for why
# this is a module rather than a superclass.
module LinkContractPersonContract
  TOOL_NAME = "link_contract_person"

  def self.included(base)
    base.description <<~DESC
      Link a Contract to a Person named on it\n      (e.g. "Principal Investigator", "Technical Contact", "Contracting Officer").
      Creates the ContractPerson edge if one doesn't already exist, then inserts a new
      ContractPersonDetail attached to the active SourceProcessingReport, attaches the
      named ContractPersonType, and updates the edge's current detail pointer. Use after
      upsert_contract and upsert_person.
    DESC

    base.param :contract_id, type: "integer", desc: "Contract.id from upsert_contract."
    base.param :person_id, type: "integer", desc: "Person.id from upsert_person."
    base.param :type, type: "string",
               desc: "Name of the ContractPersonType to attach (e.g. 'Principal Investigator'). Must already exist."
    base.param :as_of, type: "string",
               desc: "ISO 8601 datetime the relationship was effective. Defaults to now.",
               required: false
    base.param :confidence_tenths, type: "integer",
               desc: "Confidence 0–1000 (1000 = 100%). Defaults to 800. Lower it where the link " \
                     "is your inference rather than something the source states.",
               required: false
    base.param :additional_attributes, type: "object",
               desc: "Flat map of string keys to scalar values (e.g. title, since).",
               required: false
  end

  def name = TOOL_NAME
end
