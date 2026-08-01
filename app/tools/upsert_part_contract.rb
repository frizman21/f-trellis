# The contract for `upsert_part` — its name, its description and its parameter
# schema — separated from what it does with a call, so the writing tool and the
# recording stand-in an evaluation runs cannot drift apart. See
# UpsertOrganizationContract for why this is a module rather than a superclass.
#
# The description is built per instance rather than fixed, because the useful
# half of it is the taxonomy: which part types exist and what each is measured
# in. A model told that a Battery has `capacity` in mAh returns 5000; a model
# told nothing returns "5000mAh" as a string, or "5 Ah", and neither is
# comparable with anything.
module UpsertPartContract
  TOOL_NAME = "upsert_part"

  def self.included(base)
    base.params do
      array :parts, description: "Every part, component or product found on the page." do
        object do
          string :name, description: "The part's name or model designation as written on the source."
          array :part_types,
                description: "Names of the part types this part is, from the list in the tool description. " \
                             "Give every one that applies — a part is measured by the parameters of all of them." do
            string
          end
          integer :confidence_tenths,
                  description: "Confidence 0–1000 (1000 = 100%). Defaults to 800.",
                  required: false
          array :specifications,
                description: "Measured values for this part. Only parameters declared by the part's " \
                             "types are recorded; anything else belongs in additional_attributes.",
                required: false do
            object do
              string :parameter, description: "The parameter name exactly as listed in the tool description."
              string :value,
                     description: "The value, converted into the parameter's declared unit. " \
                                  "Digits only for a numeric parameter — '1.375', not '1.375 lb'."
              string :unit,
                     description: "The unit your value is in. Must match the parameter's declared unit — " \
                                  "convert before answering rather than reporting a different unit.",
                     required: false
              string :as_stated,
                     description: "What the page said, in its own words and units, e.g. '624 g'. " \
                                  "Give this whenever you converted.",
                     required: false
            end
          end
          array :additional_attributes,
                description: "Extra detail fields as key/value pairs, for anything that is not a " \
                             "declared parameter. Omit if there are none.",
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
      Record every Part found on the page in ONE call — pass them all in the
      parts array rather than calling this tool repeatedly.

      For each entry: find an existing Part by name — matched case-insensitively
      on the current detail — or create a new one. Always inserts a new
      PartDetail attached to the active SourceProcessingReport, attaches the
      named PartTypes, records the specifications, and updates the Part's current
      detail pointer.

      A part must name at least one part type from the list below; the types
      decide which parameters can be recorded for it, and a part carrying two
      types is measured by both sets.

      Give every specification in the parameter's declared unit, converting where
      the page uses another, and put the page's own wording in `as_stated` so the
      conversion can be checked. A value in the wrong unit is rejected rather
      than stored, because a column of weights in mixed units compares nothing.

      Part types and what each is measured by:
      #{taxonomy}

      Returns a results array, in the same order as the input, each entry giving
      the part_id, the new detail_id, whether the Part was newly created, how
      many specifications were recorded, and any that were not. An entry that
      could not be recorded returns an error in its slot; the remaining entries
      are still recorded.
    DESC
  end

  private

  def taxonomy
    types = PartType.includes(:part_type_parameters).order(:name)
    return "  (none configured — no parts can be recorded until part types exist)" if types.empty?

    types.map do |type|
      parameters = type.part_type_parameters.map { |p| p.text? ? "#{p.name} (text)" : p.label }
      measured = parameters.any? ? parameters.join(", ") : "no parameters declared"
      "  - #{type.name}: #{measured}"
    end.join("\n")
  end
end
