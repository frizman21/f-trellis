# The contract for `upsert_science` — its name, its description and its parameter
# schema — separated from what it does with a call, so the writing tool and the
# recording stand-in an evaluation runs cannot drift apart. See
# UpsertOrganizationContract for why this is a module rather than a superclass.
#
# The description is built per instance rather than fixed, because the useful
# half of it is the taxonomy: a model told which science types exist puts a
# finding in one of them, and a model told nothing invents a name nobody can
# query on.
module UpsertScienceContract
  include EntityTypeLookup

  TOOL_NAME = "upsert_science"

  def self.included(base)
    base.params do
      array :sciences, description: "Every science the source describes." do
        object do
          string :name, description: "The field, discipline or scientific principle, named as a subject rather than as a paper title — 'Magnetohydrodynamics', not 'On the flow of conducting fluids'."
          string :summary,
                 description: "One sentence saying what this science is about, in the source's own terms.",
                 required: false
          array :science_types,
                description: "Names of the science types this is, from the list in the tool description. " \
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
      Record every Science the source describes in ONE call — pass them all in the
      sciences array rather than calling this tool repeatedly.

      A Science is the body of knowledge or the principle at work — a field, an effect, a
      law, a phenomenon. It is not the paper, not the experiment and not the
      product built on it.

      For each entry: find an existing Science by name — matched case-insensitively
      on the current detail — or create a new one. Always inserts a new
      ScienceDetail attached to the active SourceProcessingReport, attaches the
      named ScienceTypes, and updates the Science's current detail pointer.

      Science types:
      #{taxonomy_list(ScienceType)}

      Returns a results array, in the same order as the input, each entry giving
      the science_id, the new detail_id, whether the Science was newly created, and
      any type names that are not configured. An entry that could not be recorded
      returns an error in its slot; the remaining entries are still recorded.
    DESC
  end
end
