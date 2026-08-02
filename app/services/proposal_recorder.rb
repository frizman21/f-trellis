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
    @labels = { person: {}, organization: {} }
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

  def record_person_organization(person_id:, organization_id:, relationship_type:, attributes: nil)
    add("person_organization",
        "person" => label_for(:person, person_id),
        "organization" => label_for(:organization, organization_id),
        "relationship_type" => normalize(relationship_type),
        "attributes" => normalize_attributes(attributes))

    next_id(:person_organization)
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

  # The name behind a synthetic id, or nil for one this run never issued. The
  # link tools use nil to return the same "no person #5" error the writing tool
  # would — a stand-in that quietly accepted a made-up id would let a model get
  # away with something the real run would have rejected.
  def label_for(kind, id)
    @labels.fetch(kind)[id.to_i]
  end

  # Details are inserted one per entry by the writing tools, so the stand-ins
  # hand back an id per entry too.
  def next_detail_id = next_id(:detail)

  private

  def add(type, attributes)
    @proposals << attributes.compact.merge("type" => type).sort.to_h
  end

  def identify(kind, label)
    known = @labels.fetch(kind)
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

  def normalize_attributes(attributes)
    sanitize_attrs(attributes).transform_values { |v| v.is_a?(String) ? normalize(v) : v }
                              .sort.to_h
  end
end
