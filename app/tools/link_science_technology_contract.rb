# The contract for `link_science_technology`, shared by the writing tool and the recording
# stand-in an evaluation runs instead. See UpsertOrganizationContract for why
# this is a module rather than a superclass.
module LinkScienceTechnologyContract
  TOOL_NAME = "link_science_technology"

  def self.included(base)
    base.description <<~DESC
      Link a Science to a Technology that applies it or is derived from it
      (e.g. "Application", "Derived From", "Enabling Principle").
      Creates the ScienceTechnology edge if one doesn't already exist, then inserts a new
      ScienceTechnologyDetail attached to the active SourceProcessingReport, attaches the
      named ScienceTechnologyType, and updates the edge's current detail pointer. Use after
      upsert_science and upsert_technology.
    DESC

    base.param :science_id, type: "integer", desc: "Science.id from upsert_science."
    base.param :technology_id, type: "integer", desc: "Technology.id from upsert_technology."
    base.param :type, type: "string",
               desc: "Name of the ScienceTechnologyType to attach (e.g. 'Application'). Must already exist."
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
