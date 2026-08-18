# Collects what a run *would* have written into the knowledge graph.
#
# The recording tools an evaluation registers hand their entries here instead of
# creating rows. Two jobs beyond collecting:
#
# 1. **Synthetic ids.** The real upsert tools hand back a Person.id the model
#    then passes to `link_person_organization`, so the stand-ins have to hand
#    back something in the same shape. These ids are per-run counters and mean
#    nothing outside it.
# 2. **Resolving those ids back to names.** A link recorded as "person 1 works
#    at organization 2" would compare differently between two runs that proposed
#    the same links in a different order. Recorded against the names instead, it
#    compares.
#
# Values are normalised on the way in — downcased and stripped — because the
# whole point of the record is comparing one run against another, and "Acme
# Corp" and "acme corp" are the same contribution.
class ProposalRecorder
  # sanitize_attrs, which already handles both attribute shapes the tools accept
  # (a flat hash, or the [{key:, value:}] array the strict schemas require).
  include EntityUpsert

  def initialize
    @proposals = []
    # One id space per kind, mirroring the real tables: a Person #1 and an
    # Organization #1 both exist, and a link tool has to resolve the right one.
    @labels = Hash.new { |kinds, kind| kinds[kind] = {} }
    @counters = Hash.new(0)
  end

  def proposals = @proposals.dup

  # [id, created] — `created` is false for a name already seen in this run,
  # which is what the writing tool reports when it matches an existing row.
  def record_person(first_name:, last_name:, attributes: nil)
    label = normalize([ first_name, last_name ].join(" "))
    id, created = identify(:person, label)

    add("person",
        "first_name" => normalize(first_name),
        "last_name" => normalize(last_name),
        "attributes" => normalize_attributes(attributes))

    [ id, created ]
  end

  def record_organization(name:, acronym: nil, attributes: nil)
    label = normalize(name)
    id, created = identify(:organization, label)

    add("organization",
        "name" => label,
        "acronym" => normalize(acronym).presence,
        "attributes" => normalize_attributes(attributes))

    [ id, created ]
  end

  # Specifications ride along inside the part's record rather than being
  # proposals of their own: "this drone weighs 1.375 lb" is not a separate
  # contribution from "this drone exists", and counting it as one would let a
  # model out-rank another by listing more numbers about the same part.
  def record_part(name:, part_types:, specifications: [], attributes: nil)
    label = normalize(name)
    id, created = identify(:part, label)

    add("part",
        "name" => label,
        "part_types" => Array(part_types).map { |t| normalize(t) }.sort,
        "specifications" => Array(specifications).map { |spec| normalize_specification(spec) }.sort_by(&:to_s),
        "attributes" => normalize_attributes(attributes))

    [ id, created ]
  end

  # Summary rides along with the name rather than being a proposal of its own:
  # "this paper is about magnetohydrodynamics" and "here is what that is" are
  # one contribution, and counting them separately would let a model out-rank
  # another by writing more prose about the same field.
  def record_science(name:, summary: nil, science_types: [], attributes: nil)
    label = normalize(name)
    id, created = identify(:science, label)

    add("science",
        "name" => label,
        "summary" => normalize(summary).presence,
        "science_types" => Array(science_types).map { |t| normalize(t) }.sort,
        "attributes" => normalize_attributes(attributes))

    [ id, created ]
  end

  def record_technology(name:, summary: nil, technology_types: [], attributes: nil)
    label = normalize(name)
    id, created = identify(:technology, label)

    add("technology",
        "name" => label,
        "summary" => normalize(summary).presence,
        "technology_types" => Array(technology_types).map { |t| normalize(t) }.sort,
        "attributes" => normalize_attributes(attributes))

    [ id, created ]
  end

  # The identifier is the label, not the title: two runs that both found award
  # FA2541-26-C-B007 agree, whether one read the title off the header and the
  # other off the abstract.
  def record_contract(identifier:, title: nil, value_usd: nil, contract_types: [], attributes: nil)
    label = normalize(identifier)
    id, created = identify(:contract, label)

    add("contract",
        "identifier" => label,
        "title" => normalize(title).presence,
        "value_usd" => normalize(value_usd).presence,
        "contract_types" => Array(contract_types).map { |t| normalize(t) }.sort,
        "attributes" => normalize_attributes(attributes))

    [ id, created ]
  end

  def record_person_organization(person_id:, organization_id:, relationship_type:, attributes: nil)
    add("person_organization",
        "person" => label_for(:person, person_id),
        "organization" => label_for(:organization, organization_id),
        "relationship_type" => normalize(relationship_type),
        "attributes" => normalize_attributes(attributes))

    next_id(:person_organization)
  end

  def record_part_organization(part_id:, organization_id:, relationship_type:, attributes: nil)
    add("part_organization",
        "part" => label_for(:part, part_id),
        "organization" => label_for(:organization, organization_id),
        "relationship_type" => normalize(relationship_type),
        "attributes" => normalize_attributes(attributes))

    next_id(:part_organization)
  end

  def record_part_technology(part_id:, technology_id:, relationship_type:, attributes: nil)
    add("part_technology",
        "part" => label_for(:part, part_id),
        "technology" => label_for(:technology, technology_id),
        "relationship_type" => normalize(relationship_type),
        "attributes" => normalize_attributes(attributes))

    next_id(:part_technology)
  end

  def record_science_technology(science_id:, technology_id:, relationship_type:, attributes: nil)
    add("science_technology",
        "science" => label_for(:science, science_id),
        "technology" => label_for(:technology, technology_id),
        "relationship_type" => normalize(relationship_type),
        "attributes" => normalize_attributes(attributes))

    next_id(:science_technology)
  end

  def record_person_science(person_id:, science_id:, relationship_type:, attributes: nil)
    add("person_science",
        "person" => label_for(:person, person_id),
        "science" => label_for(:science, science_id),
        "relationship_type" => normalize(relationship_type),
        "attributes" => normalize_attributes(attributes))

    next_id(:person_science)
  end

  def record_contract_organization(contract_id:, organization_id:, relationship_type:, attributes: nil)
    add("contract_organization",
        "contract" => label_for(:contract, contract_id),
        "organization" => label_for(:organization, organization_id),
        "relationship_type" => normalize(relationship_type),
        "attributes" => normalize_attributes(attributes))

    next_id(:contract_organization)
  end

  def record_contract_person(contract_id:, person_id:, relationship_type:, attributes: nil)
    add("contract_person",
        "contract" => label_for(:contract, contract_id),
        "person" => label_for(:person, person_id),
        "relationship_type" => normalize(relationship_type),
        "attributes" => normalize_attributes(attributes))

    next_id(:contract_person)
  end

  def record_contract_technology(contract_id:, technology_id:, relationship_type:, attributes: nil)
    add("contract_technology",
        "contract" => label_for(:contract, contract_id),
        "technology" => label_for(:technology, technology_id),
        "relationship_type" => normalize(relationship_type),
        "attributes" => normalize_attributes(attributes))

    next_id(:contract_technology)
  end

  def record_contract_part(contract_id:, part_id:, relationship_type:, attributes: nil)
    add("contract_part",
        "contract" => label_for(:contract, contract_id),
        "part" => label_for(:part, part_id),
        "relationship_type" => normalize(relationship_type),
        "attributes" => normalize_attributes(attributes))

    next_id(:contract_part)
  end

  def record_organization_technology(organization_id:, technology_id:, relationship_type:, attributes: nil)
    add("organization_technology",
        "organization" => label_for(:organization, organization_id),
        "technology" => label_for(:technology, technology_id),
        "relationship_type" => normalize(relationship_type),
        "attributes" => normalize_attributes(attributes))

    next_id(:organization_technology)
  end

  def record_person_person(person_a_id:, person_b_id:, relationship_type:, attributes: nil)
    # Keyed on the unordered pair, exactly as the writing tool keys the edge:
    # proposing A–B and proposing B–A is the same contribution.
    pair = [ label_for(:person, person_a_id), label_for(:person, person_b_id) ].sort

    add("person_person",
        "people" => pair,
        "relationship_type" => normalize(relationship_type),
        "attributes" => normalize_attributes(attributes))

    next_id(:person_person)
  end

  def record_organization_organization(organization_a_id:, organization_b_id:, relationship_type:, attributes: nil)
    # The writing tool keys the edge on the unordered pair, so the record does
    # too: proposing A–B and proposing B–A are the same contribution.
    pair = [ label_for(:organization, organization_a_id), label_for(:organization, organization_b_id) ].sort

    add("organization_organization",
        "organizations" => pair,
        "relationship_type" => normalize(relationship_type),
        "attributes" => normalize_attributes(attributes))

    next_id(:organization_organization)
  end

  # Vocabulary a run proposed, via the recording stand-ins for the type-creating
  # tools. Deliberately *not* a proposal: naming "Mentorship" is not a
  # contribution to the knowledge base, and counting it as one would let a model
  # out-rank another by inventing names rather than by reading the page. What a
  # new type is worth shows up in whether the run then used it — and the link
  # proposal records that, against the name.
  def record_relationship_type(kind, name:)
    identify(:"#{kind}_type", normalize(name))
  end

  # True for a type name this run minted. The recording link tools accept those
  # alongside the configured ones: in a real run the type would have been created
  # for real a moment earlier, so refusing the link here would fail a model for
  # something the writing run allows.
  def minted_relationship_type?(kind, name)
    @labels[:"#{kind}_type"].value?(normalize(name))
  end

  # The name behind a synthetic id, or nil for one this run never issued. The
  # link tools use nil to return the same "no person #5" error the writing tool
  # would — a stand-in that quietly accepted a made-up id would let a model get
  # away with something the real run would have rejected.
  def label_for(kind, id)
    @labels[kind][id.to_i]
  end

  # Details are inserted one per entry by the writing tools, so the stand-ins
  # hand back an id per entry too.
  def next_detail_id = next_id(:detail)

  private

  def add(type, attributes)
    @proposals << attributes.compact.merge("type" => type).sort.to_h
  end

  def identify(kind, label)
    known = @labels[kind]
    existing = known.key(label)
    return [ existing, false ] if existing

    id = next_id(kind)
    known[id] = label
    [ id, true ]
  end

  def next_id(kind)
    @counters[kind] += 1
  end

  def normalize(value) = value.to_s.strip.downcase

  # Compared on parameter, value and unit. `as_stated` is deliberately left out:
  # two runs that both put the weight at 1.375 lb agree, whether one read "624 g"
  # and the other "1.375 lbs".
  def normalize_specification(spec)
    spec = spec.stringify_keys
    { "parameter" => normalize(spec["parameter"]),
      "value" => normalize(spec["value"]),
      "unit" => normalize(spec["unit"]).presence }.compact
  end

  def normalize_attributes(attributes)
    sanitize_attrs(attributes).transform_values { |v| v.is_a?(String) ? normalize(v) : v }
                              .sort.to_h
  end
end
