# The contract for `create_person_person_type`, shared by the writing tool and
# the recording stand-in an evaluation runs instead. See
# UpsertOrganizationContract for why this is a module rather than a superclass.
module CreatePersonPersonTypeContract
  TOOL_NAME = "create_person_person_type"
  PAIR = "Person ↔ Person".freeze

  def self.included(base)
    RelationshipTypeContract.declare_params(base, pair: PAIR)
  end

  def name = TOOL_NAME

  def description
    RelationshipTypeContract.describe(
      type_class: PersonPersonType,
      pair: PAIR,
      purpose: "`link_person_person` draws on.",
      example: "Co-Founder",
      counter_example: "Ada and Alan's work on the Analytical Engine"
    )
  end
end
