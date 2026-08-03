# The contract for `create_person_organization_type`, shared by the writing tool
# and the recording stand-in an evaluation runs instead. See
# UpsertOrganizationContract for why this is a module rather than a superclass.
module CreatePersonOrganizationTypeContract
  TOOL_NAME = "create_person_organization_type"
  PAIR = "Person ↔ Organization".freeze

  def self.included(base)
    RelationshipTypeContract.declare_params(base, pair: PAIR)
  end

  def name = TOOL_NAME

  def description
    RelationshipTypeContract.describe(
      type_class: PersonOrganizationType,
      pair: PAIR,
      purpose: "`link_person_organization` draws on.",
      example: "Board Membership",
      counter_example: "Jane Doe's seat on the Acme board"
    )
  end
end
