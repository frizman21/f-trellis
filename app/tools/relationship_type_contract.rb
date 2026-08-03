# The parameter schema and description shared by the tools that let a model
# extend the relationship-type vocabulary. Both `create_person_organization_type`
# and `create_person_person_type` ask for the same three things and warn against
# the same failure, so the wording lives here rather than being written twice and
# drifting.
#
# Like the other contracts, this is what the writing tool and the recording
# stand-in an evaluation runs both present, so the model cannot tell them apart.
module RelationshipTypeContract
  # The list of existing types is built per call rather than fixed, for the same
  # reason UpsertPartContract builds its taxonomy that way: the useful half of
  # the description is what already exists. A model that cannot see "Employment"
  # in the list invents "Employed By", and the vocabulary ends up with three
  # spellings of one idea — the one real risk of handing minting rights to a model.
  def self.declare_params(base, pair:)
    base.params do
      string :name,
             description: "Name of the new #{pair} relationship type, in title case " \
                          "(e.g. 'Board Membership'). Name the kind of relationship, not the parties in it."
      string :description,
             description: "One sentence saying what the relationship means, so a later reader " \
                          "can tell this type apart from its neighbours."
      array :additional_attribute_keys,
            description: "Field names a relationship of this type is expected to carry " \
                         "(e.g. 'title', 'start_date'). Omit if there are none.",
            required: false do
        string
      end
    end
  end

  def self.describe(type_class:, pair:, purpose:, example:, counter_example:)
    <<~DESC
      Create a new #{pair} relationship type — the named vocabulary #{purpose}

      Call this only when a relationship on the page fits none of the types
      listed below. These types are shared across every source in the knowledge
      base, so name one for the kind of relationship rather than for the parties
      in it: "#{example}", not "#{counter_example}".

      A name already in the list returns that type unchanged instead of creating
      a second spelling of it, so a duplicate call is harmless.

      Existing #{pair} types:
      #{vocabulary(type_class)}

      Returns the type's id, its name, and whether it was newly created.
    DESC
  end

  def self.vocabulary(type_class)
    types = type_class.order(:name)
    return "  (none configured yet)" if types.empty?

    types.map do |type|
      meaning = type.description.presence || "no description recorded"
      keys = type.additional_attribute_keys.presence
      line = "  - #{type.name}: #{meaning}"
      keys ? "#{line} [attributes: #{keys.join(', ')}]" : line
    end.join("\n")
  end
end
