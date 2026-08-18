# The contract for `upsert_contract` — its name, its description and its
# parameter schema — separated from what it does with a call, so the writing
# tool and the recording stand-in an evaluation runs cannot drift apart. See
# UpsertOrganizationContract for why this is a module rather than a superclass.
#
# The word "contract" is doing double duty here: this module is the *tool*
# contract, and the entity it records is a Contract. Nothing to be done about
# that beyond saying so.
module UpsertContractContract
  include EntityTypeLookup

  TOOL_NAME = "upsert_contract"

  def self.included(base)
    base.params do
      array :contracts, description: "Every contract, award or grant the source names." do
        object do
          string :identifier,
                 description: "The contract, award or grant number exactly as written, " \
                              "e.g. 'FA2541-26-C-B007' or 'DE-AR0001963'. This is what identifies " \
                              "the contract; do not substitute the project title."
          string :title, description: "The contract's title, if the source gives one.", required: false
          string :value_usd,
                 description: "Award value in US dollars, digits only — '1699936.24', not '$1.7M'. " \
                              "Omit rather than convert a figure given in another currency.",
                 required: false
          string :start_date, description: "ISO 8601 date the contract starts, e.g. 2026-01-23.", required: false
          string :end_date, description: "ISO 8601 date the contract ends.", required: false
          array :contract_types,
                description: "Names of the contract types this is, from the list in the tool description. " \
                             "Omit rather than guess at a name that is not listed.",
                required: false do
            string
          end
          integer :confidence_tenths,
                  description: "Confidence 0–1000 (1000 = 100%). Defaults to 800.",
                  required: false
          array :additional_attributes,
                description: "Extra detail fields as key/value pairs — phase, program, " \
                             "solicitation number, agency tracking number. Omit if there are none.",
                required: false do
            object do
              string :key, description: "Field name."
              string :value, description: "Field value."
            end
          end
        end
      end
    end
  end

  def name = TOOL_NAME

  def description
    <<~DESC
      Record every Contract the source names in ONE call — pass them all in the
      contracts array rather than calling this tool repeatedly.

      A Contract is a funded agreement: a contract, an award, a grant, a task
      order. It is the thing that connects an organization to the technology it
      is paid to build, so record it whenever a source states one, then use
      link_contract_organization, link_contract_person, link_contract_technology
      and link_contract_part to say who and what it covers.

      Only record a contract the source actually names. A paper that mentions it
      was funded, without giving a number, has no Contract in it — the funding
      organization goes on link_organization_technology instead.

      For each entry: find an existing Contract by identifier — matched
      case-insensitively on the current detail — or create a new one. Always
      inserts a new ContractDetail attached to the active
      SourceProcessingReport, attaches the named ContractTypes, and updates the
      Contract's current detail pointer.

      Contract types:
      #{taxonomy_list(ContractType)}

      Returns a results array, in the same order as the input, each entry giving
      the contract_id, the new detail_id, whether the Contract was newly
      created, and any type names that are not configured. An entry that could
      not be recorded returns an error in its slot; the remaining entries are
      still recorded.
    DESC
  end
end
