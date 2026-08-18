# The contract for `upsert_technology` — its name, its description and its parameter
# schema — separated from what it does with a call, so the writing tool and the
# recording stand-in an evaluation runs cannot drift apart. See
# UpsertOrganizationContract for why this is a module rather than a superclass.
#
# The description is built per instance rather than fixed, because the useful
# half of it is the taxonomy: a model told which technology types exist puts a
# finding in one of them, and a model told nothing invents a name nobody can
# query on.
module UpsertTechnologyContract
  include EntityTypeLookup

  TOOL_NAME = "upsert_technology"

  def self.included(base)
    base.params do
      array :technologies, description: "Every technology the source describes." do
        object do
          string :name, description: "The engineered capability or method, named generically rather than by brand — 'solid-state lithium battery', not 'PowerCell 9000'."
          string :summary,
                 description: "One sentence saying what this technology does, in the source's own terms.",
                 required: false
          array :technology_types,
                description: "Names of the technology types this is, from the list in the tool description. " \
                             "Give every one that applies. Omit rather than guess at a name that is not listed.",
                required: false do
            string
          end
          integer :confidence_tenths,
                  description: "Confidence 0–1000 (1000 = 100%). Defaults to 800.",
                  required: false
          array :additional_attributes,
                description: "Extra detail fields as key/value pairs. Omit if there are none.",
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
      Record every Technology the source describes in ONE call — pass them all in the
      technologies array rather than calling this tool repeatedly.

      A Technology is an engineered capability or method: a way of making or doing
      something. It is not the science it rests on, and it is not a specific
      product — a named product is a Part, recorded with upsert_part.

      For each entry: find an existing Technology by name — matched case-insensitively
      on the current detail — or create a new one. Always inserts a new
      TechnologyDetail attached to the active SourceProcessingReport, attaches the
      named TechnologyTypes, and updates the Technology's current detail pointer.

      Technology types:
      #{taxonomy_list(TechnologyType)}

      Returns a results array, in the same order as the input, each entry giving
      the technology_id, the new detail_id, whether the Technology was newly created, and
      any type names that are not configured. An entry that could not be recorded
      returns an error in its slot; the remaining entries are still recorded.
    DESC
  end
end
