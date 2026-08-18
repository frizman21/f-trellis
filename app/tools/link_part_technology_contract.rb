# The contract for `link_part_technology`, shared by the writing tool and the recording
# stand-in an evaluation runs instead. See UpsertOrganizationContract for why
# this is a module rather than a superclass.
module LinkPartTechnologyContract
  TOOL_NAME = "link_part_technology"

  def self.included(base)
    base.description <<~DESC
      Link a Part to a Technology it implements, embodies or depends on
      (e.g. "Implementation", "Dependency", "Enabler").
      Creates the PartTechnology edge if one doesn't already exist, then inserts a new
      PartTechnologyDetail attached to the active SourceProcessingReport, attaches the
      named PartTechnologyType, and updates the edge's current detail pointer. Use after
      upsert_part and upsert_technology.
    DESC

    base.param :part_id, type: "integer", desc: "Part.id from upsert_part."
    base.param :technology_id, type: "integer", desc: "Technology.id from upsert_technology."
    base.param :type, type: "string",
               desc: "Name of the PartTechnologyType to attach (e.g. 'Implementation'). Must already exist."
    base.param :as_of, type: "string",
               desc: "ISO 8601 datetime the relationship was effective. Defaults to now.",
               required: false
    base.param :confidence_tenths, type: "integer",
               desc: "Confidence 0–1000 (1000 = 100%). Defaults to 800. Lower it where the link " \
                     "is your inference rather than something the source states.",
               required: false
    base.param :additional_attributes, type: "object",
               desc: "Flat map of string keys to scalar values (e.g. since, subsystem).",
               required: false
  end

  def name = TOOL_NAME
end
