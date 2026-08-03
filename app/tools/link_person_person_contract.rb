# The contract for `link_person_person`, shared by the writing tool and the
# recording stand-in an evaluation runs instead. See UpsertOrganizationContract
# for why this is a module rather than a superclass.
module LinkPersonPersonContract
  TOOL_NAME = "link_person_person"

  def self.included(base)
    base.description <<~DESC
      Link two People with a named relationship type (e.g. "Co-Founder",
      "Mentorship"). Creates the PersonPerson edge if one doesn't already exist
      (the edge is keyed on the unordered pair of people, so calling with the
      two in either order reuses the same edge), then inserts a new
      PersonPersonDetail attached to the active SourceProcessingReport, attaches
      the named PersonPersonType, and updates the edge's current detail pointer.
      Use after upsert_person.

      For asymmetric relationship types where direction matters (e.g.
      "Mentorship" — one person mentors the other), encode the direction by
      including direction-coding keys in `additional_attributes` (for
      Mentorship: `mentor_person_id` and `mentee_person_id`).

      If no existing type fits the relationship, call
      create_person_person_type first and pass the name it returns.
    DESC

    base.param :person_a_id, type: "integer",
               desc: "Person.id of one side of the relationship from upsert_person."
    base.param :person_b_id, type: "integer",
               desc: "Person.id of the other side from upsert_person."
    base.param :type, type: "string",
               desc: "Name of the PersonPersonType to attach (e.g. 'Co-Founder'). Must already exist."
    base.param :as_of, type: "string",
               desc: "ISO 8601 datetime the relationship was effective. Defaults to now.",
               required: false
    base.param :confidence_tenths, type: "integer",
               desc: "Confidence 0–1000 (1000 = 100%). Defaults to 800.",
               required: false
    base.param :additional_attributes, type: "object",
               desc: "Flat map of string keys to scalar values. For asymmetric types include direction-coding keys (e.g. mentor_person_id, mentee_person_id).",
               required: false
  end

  def name = TOOL_NAME
end
