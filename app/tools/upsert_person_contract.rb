# The contract for `upsert_person`, shared by the writing tool and the recording
# stand-in an evaluation runs instead. See UpsertOrganizationContract for why
# this is a module rather than a superclass.
module UpsertPersonContract
  TOOL_NAME = "upsert_person"

  def self.included(base)
    base.description <<~DESC
      Record every Person found on the page in ONE call — pass them all in the
      people array rather than calling this tool repeatedly.

      For each entry: find an existing Person by (first_name, last_name) — matched
      case-insensitively on the current detail — or create a new one. Always
      inserts a new PersonDetail attached to the active SourceProcessingReport,
      updating the Person's current detail pointer.

      Returns a results array, in the same order as the input, each entry giving
      the person_id, the new detail_id, and whether the Person was newly created.
      An entry that could not be recorded returns an error in its slot; the
      remaining entries are still recorded.
    DESC

    base.params do
      array :people, description: "Every person found on the page." do
        object do
          string :first_name, description: "The person's given name."
          string :last_name, description: "The person's family name."
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
end
