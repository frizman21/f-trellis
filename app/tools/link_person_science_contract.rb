# The contract for `link_person_science`, shared by the writing tool and the recording
# stand-in an evaluation runs instead. See UpsertOrganizationContract for why
# this is a module rather than a superclass.
module LinkPersonScienceContract
  TOOL_NAME = "link_person_science"

  def self.included(base)
    base.description <<~DESC
      Link a Person to a Science they research, author in or contribute to
      (e.g. "Researcher", "Author", "Contributor").
      Creates the PersonScience edge if one doesn't already exist, then inserts a new
      PersonScienceDetail attached to the active SourceProcessingReport, attaches the
      named PersonScienceType, and updates the edge's current detail pointer. Use after
      upsert_person and upsert_science.
    DESC

    base.param :person_id, type: "integer", desc: "Person.id from upsert_person."
    base.param :science_id, type: "integer", desc: "Science.id from upsert_science."
    base.param :type, type: "string",
               desc: "Name of the PersonScienceType to attach (e.g. 'Researcher'). Must already exist."
    base.param :as_of, type: "string",
               desc: "ISO 8601 datetime the relationship was effective. Defaults to now.",
               required: false
    base.param :confidence_tenths, type: "integer",
               desc: "Confidence 0–1000 (1000 = 100%). Defaults to 800. Lower it where the link " \
                     "is your inference rather than something the source states.",
               required: false
    base.param :additional_attributes, type: "object",
               desc: "Flat map of string keys to scalar values (e.g. since, institution, role).",
               required: false
  end

  def name = TOOL_NAME
end
