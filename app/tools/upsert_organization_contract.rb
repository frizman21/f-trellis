# The contract for `upsert_organization` — its name, its description and its
# parameter schema — separated from what it does with a call.
#
# UpsertOrganizationTool writes rows; RecordingUpsertOrganizationTool records
# what would have been written. Both must present the *identical* contract, or
# an evaluation stops measuring the thing it claims to: a model that sees a
# different tool name or a different schema behaves differently. RubyLLM keeps
# `description` and `params` in class-level ivars and does not inherit them
# down a subclass, so sharing means a module, not a superclass.
module UpsertOrganizationContract
  TOOL_NAME = "upsert_organization"

  def self.included(base)
    base.description <<~DESC
      Record every Organization found on the page in ONE call — pass them all in
      the organizations array rather than calling this tool repeatedly.

      For each entry: find an existing Organization by name — matched
      case-insensitively on the current detail — or create a new one. Always
      inserts a new OrganizationDetail attached to the active
      SourceProcessingReport, updating the Organization's current detail pointer.
      Pass the acronym whenever the source states one or you know it.

      Returns a results array, in the same order as the input, each entry giving
      the organization_id, the new detail_id, and whether the Organization was
      newly created. An entry that could not be recorded returns an error in its
      slot; the remaining entries are still recorded.
    DESC

    base.params do
      array :organizations, description: "Every organization found on the page." do
        object do
          string :name, description: "The organization's name as written on the source."
          string :acronym,
                 description: "The organization's acronym or initialism, e.g. NASA. Omit if unknown.",
                 required: false
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

  # RubyLLM derives the tool name from the class name, which would make the
  # recording stand-in announce itself as `recording_upsert_organization`.
  def name = TOOL_NAME
end
