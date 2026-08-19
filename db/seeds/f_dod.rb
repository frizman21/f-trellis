# The F-DoD landscape: the tier 1 knowledge model removed in #4, rebuilt as
# ontology in the project it was built for. See change request #13.
#
# Written as data walked by a few lines of code rather than as hundreds of
# find_or_create_by! calls, so the landscape can be read as a landscape.
#
# Entity names are a column (#28), so no type declares a `name` attribute —
# a type declaring one alongside the column would be two places for one fact.

project = Project.find_or_create_by!(name: "F-DoD") do |p|
  p.name = "F-DoD"
end

# --- The six kinds of thing ------------------------------------------------
#
# Attributes are the columns the removed *_details tables actually carried. Two
# do not survive intact: the ontology's value types are int, float, string and
# datetime, so a contract's dates become datetime and its value becomes float.

ENTITY_TYPES = {
  "Person" => {
    description: <<~TEXT.squish,
      An individual human being named in the source. Record people who take part in
      the subject matter: engineers, researchers, officials, executives, or the authors of
      the work being described. Do not record the journalist or editor who wrote the source
      itself, people named only in a passing comparison, or a job title with no named
      holder. A team, an office, or a committee is an Organization, not a Person.
    TEXT
    attributes: { "first_name" => "string", "last_name" => "string" }
  },
  "Organization" => {
    description: <<~TEXT.squish,
      A company, government agency, laboratory, university, programme office, or other
      named body that acts as a unit. Record it when the source treats it as an actor:
      awarding, building, funding, employing, regulating, or operating something. Record a
      named division or subunit as its own Organization when the source names it separately
      from its parent. Do not record a place, a product line, or a project name as an
      Organization; a named built thing is a Part.
    TEXT
    attributes: { "acronym" => "string" }
  },
  "Science" => {
    description: <<~TEXT.squish,
      A body of knowledge about how the world behaves: a field, a discipline, a principle,
      a law, or an observed effect. Record it when the source invokes it as the reason
      something works or as the subject of research. Do not record a way of doing something,
      which is a Technology, and do not record a specific built object, which is a Part.
      Superconductivity is a Science; superconducting magnet design is a Technology.
    TEXT
    attributes: { "summary" => "string" }
  },
  "Technology" => {
    description: <<~TEXT.squish,
      An engineered capability: a method, process, technique, material, or class of device
      that can be applied to make something happen. Record it when the source describes a way
      of achieving something that could be applied more than once. Do not record a single
      built artefact or product, which is a Part, and do not record the underlying physics,
      which is a Science. Stealth shaping is a Technology; a particular aircraft built using
      it is a Part.
    TEXT
    attributes: { "summary" => "string" }
  },
  "Part" => {
    description: <<~TEXT.squish,
      A concrete, built artefact with an identity of its own: an engine, a stage, a computer,
      an airframe, an instrument, a subassembly. Record it when the source names a specific
      thing that was built, is being built, or is to be delivered. Record a component
      separately when the source names it apart from the whole it belongs to. Do not record a
      capability or a method, which is a Technology, and do not record a product category
      with no named instance.
    TEXT
    attributes: { "mass_kg" => "float" }
  },
  "Contract" => {
    description: <<~TEXT.squish,
      A specific award of money for work: a contract, grant, task order, or other
      transaction agreement. Record it when the source names an award identifier, a value, a
      period of performance, or the parties to a particular award. Do not record a general
      funding relationship, a budget line, or a programme with no award behind it. A statement
      that an agency funded the work is not a Contract unless the source names the award.
    TEXT
    attributes: { "identifier" => "string", "title" => "string",
                  "start_date" => "datetime", "end_date" => "datetime",
                  "value_usd" => "float" }
  }
}.freeze

# --- The kinds of edge between them ----------------------------------------
#
# The vocabulary the removed type taxonomies carried. What used to be "a
# PersonOrganization row typed Employment" is now simply a relationship of type
# Employment, declared to run Person → Organization: the kind and the edge are
# one object now.

# What makes each kind of edge true. "Both appear on the page" is not a
# relationship, so each definition says what the source must actually state.
RELATIONSHIP_DESCRIPTIONS = {
  "Employment" => <<~TEXT.squish,
    The person is or was paid staff of the organization. Record it when the
    source states a role, a post held, or that the person works or worked there.
    A one-off consultation or a quoted opinion is not employment; use
    Affiliation when the tie is looser than a job.
  TEXT
  "Affiliation" => <<~TEXT.squish,
    The person is associated with the organization without being its staff: a
    fellow, an advisor, a board member, a visiting researcher, or a named
    collaborator. Record it when the source ties the two together but stops
    short of stating employment.
  TEXT
  "Marriage" => <<~TEXT.squish,
    The two people are or were married to each other. Record it only when the
    source says so.
  TEXT
  "Friendship" => <<~TEXT.squish,
    The two people are known associates outside a reporting line. Record it when
    the source describes a personal or professional acquaintance that is neither
    employment nor family.
  TEXT
  "Family" => <<~TEXT.squish,
    The two people are related by blood or by marriage. Record the relation the
    source states.
  TEXT
  "Partnership" => <<~TEXT.squish,
    The two organizations work together on something the source names: a joint
    venture, a teaming arrangement, a consortium, or a stated collaboration. Do
    not record two organizations merely appearing in the same document.
  TEXT
  "Subsidiary" => <<~TEXT.squish,
    The first organization is owned or controlled by the second. Record it for a
    wholly owned unit, a named division, or an acquired company. Direction
    matters: from is the owned, to is the owner.
  TEXT
  "Manufacturer" => <<~TEXT.squish,
    The organization builds or built the part. Record it when the source says
    who made the thing, including a prime contractor building it under its own
    name.
  TEXT
  "Consumer" => <<~TEXT.squish,
    The organization uses or operates the part. Record it for the fielded user,
    not for whoever paid for it.
  TEXT
  "Demand" => <<~TEXT.squish,
    The organization wants the part built or has stated a requirement for it.
    Record it for a stated need that has not yet produced an award; once an
    award exists, use the Contract relationships instead.
  TEXT
  "Composition" => <<~TEXT.squish,
    The first part is a component of the second. Record it when the source
    places one built thing inside another, and record the quantity when the
    source gives one.
  TEXT
  "Implementation" => <<~TEXT.squish,
    The part implements the technology: it is a working instance of the method
    or capability. Record it when the source says the artefact is how the
    technology was realised.
  TEXT
  "Dependency" => <<~TEXT.squish,
    The part depends on the technology to function. Record it when the source
    says the artefact could not work without it, as distinct from the artefact
    being an instance of it.
  TEXT
  "Enabler" => <<~TEXT.squish,
    The part is what made the technology practical. Record it when the source
    credits a specific built thing with making a capability usable, rather than
    the other way round.
  TEXT
  "Application" => <<~TEXT.squish,
    The technology applies the science: it puts the principle to work. Record it
    when the source explains a capability by naming the knowledge behind it.
  TEXT
  "Derived From" => <<~TEXT.squish,
    The technology came out of research in the science. Record it when the
    source describes a lineage from a field of study to an engineered
    capability.
  TEXT
  "Enabling Principle" => <<~TEXT.squish,
    The science is the reason the technology works at all. Record it for the
    fundamental effect or law the capability rests on, rather than for a field
    that merely relates to it.
  TEXT
  "Researcher" => <<~TEXT.squish,
    The person conducts or conducted research in the field. Record it when the
    source describes them working in the discipline, whether or not a
    publication is named.
  TEXT
  "Author" => <<~TEXT.squish,
    The person wrote a paper, book, or report in the field. Record it when the
    source names the person as an author of work in that discipline.
  TEXT
  "Contributor" => <<~TEXT.squish,
    The person contributed to the field without being described as a researcher
    or as an author of a named work: an advisor, a reviewer, or a named
    collaborator. Record it when the source credits them without saying they did
    the research or wrote it up.
  TEXT
  "Awardee" => <<~TEXT.squish,
    The organization holds the contract and is responsible for delivering the
    work. Record it for the prime recipient of the award.
  TEXT
  "Awarding Agency" => <<~TEXT.squish,
    The organization issued the contract and is paying for the work. Record it
    for the buyer, not for the recipient.
  TEXT
  "Subcontractor" => <<~TEXT.squish,
    The organization performs part of the work under the contract but does not
    hold it. Record it when the source names a supplier or subcontractor beneath
    a prime.
  TEXT
  "Research Institution" => <<~TEXT.squish,
    The organization performs research under the contract as a university,
    laboratory, or research centre rather than as a commercial supplier. Record
    it when the source names the institution's research role rather than a
    delivery role.
  TEXT
  "Principal Investigator" => <<~TEXT.squish,
    The person leads the technical work under the contract. Record it for the
    named lead, whatever the source calls the role.
  TEXT
  "Technical Contact" => <<~TEXT.squish,
    The person is the named technical point of contact for the contract, without
    being described as leading the work. Record it when the source gives a
    contact rather than a lead.
  TEXT
  "Contracting Officer" => <<~TEXT.squish,
    The person administers the award on the buyer's side: signing, modifying, or
    overseeing the contract itself rather than the work. Record it for the named
    administering official, not for the technical lead.
  TEXT
  "Develop" => <<~TEXT.squish,
    The contract funds developing the technology. Record it when the source says
    the award is to build or advance the capability.
  TEXT
  "Apply" => <<~TEXT.squish,
    The contract funds applying an existing technology rather than developing
    it. Record it when the award uses a capability that already exists.
  TEXT
  "Evaluate" => <<~TEXT.squish,
    The contract funds assessing or testing the technology rather than
    developing or applying it. Record it for test, trial, and assessment awards
    where nothing new is being built.
  TEXT
  "Mature" => <<~TEXT.squish,
    The contract funds raising the technology's readiness, moving it from
    demonstrated toward fielded. Record it for maturation, qualification, or
    transition rather than initial development.
  TEXT
  "Deliverable" => <<~TEXT.squish,
    The part is delivered under the contract. Record it when the source names
    the thing the award produces.
  TEXT
  "Component" => <<~TEXT.squish,
    The part is a component covered by the contract without being the contract's
    headline deliverable. Record it for a subassembly or supplied item named in
    the award alongside what the award is for.
  TEXT
  "Procurement" => <<~TEXT.squish,
    The contract buys existing parts rather than funding their development.
    Record it for a purchase of something already designed.
  TEXT
  "Developer" => <<~TEXT.squish,
    The organization builds or develops the technology. Record it for the party
    doing the engineering, whether or not an award is named.
  TEXT
  "Funder" => <<~TEXT.squish,
    The organization pays for work on the technology without necessarily doing
    it. Record it when the source names a funding role but no specific award;
    when the award is named, use the Contract relationships.
  TEXT
  "Adopter" => <<~TEXT.squish,
    The organization uses the technology in its own work or products. Record it
    for a stated user, as distinct from a developer or a funder.
  TEXT
  "Licensee" => <<~TEXT.squish,
    The organization licensed the technology from whoever owns it. Record it
    when the source names a licensing arrangement.
  TEXT
}.freeze

RELATIONSHIP_TYPES = [
  { name: "Employment",         from: "Person",       to: "Organization", attributes: { "since" => "datetime", "role" => "string" } },
  { name: "Affiliation",        from: "Person",       to: "Organization" },
  { name: "Marriage",           from: "Person",       to: "Person",       description: "The two people are married." },
  { name: "Friendship",         from: "Person",       to: "Person",       description: "The two people are known associates." },
  { name: "Family",             from: "Person",       to: "Person",       description: "The two people are related." },
  { name: "Partnership",        from: "Organization", to: "Organization" },
  { name: "Subsidiary",         from: "Organization", to: "Organization" },
  { name: "Manufacturer",       from: "Part",         to: "Organization" },
  { name: "Consumer",           from: "Part",         to: "Organization" },
  { name: "Demand",             from: "Part",         to: "Organization" },
  { name: "Composition",        from: "Part",         to: "Part",         description: "The first part is a component of the second.", attributes: { "quantity" => "int" } },
  { name: "Implementation",     from: "Part",         to: "Technology",   description: "The part implements the technology." },
  { name: "Dependency",         from: "Part",         to: "Technology",   description: "The part depends on the technology." },
  { name: "Enabler",            from: "Part",         to: "Technology",   description: "The part makes the technology practical." },
  { name: "Application",        from: "Science",      to: "Technology",   description: "The technology applies the science." },
  { name: "Derived From",       from: "Science",      to: "Technology",   description: "The technology was derived from the science." },
  { name: "Enabling Principle", from: "Science",      to: "Technology",   description: "The science is what makes the technology possible." },
  { name: "Researcher",         from: "Person",       to: "Science",      description: "The person researches the field." },
  { name: "Author",             from: "Person",       to: "Science",      description: "The person wrote in the field." },
  { name: "Contributor",        from: "Person",       to: "Science",      description: "The person contributed to the field." },
  { name: "Awardee",            from: "Contract",     to: "Organization" },
  { name: "Awarding Agency",    from: "Contract",     to: "Organization" },
  { name: "Subcontractor",      from: "Contract",     to: "Organization" },
  { name: "Research Institution", from: "Contract",   to: "Organization" },
  { name: "Principal Investigator", from: "Contract", to: "Person",       description: "The person leads the work." },
  { name: "Technical Contact",  from: "Contract",     to: "Person",       description: "The person is the technical point of contact." },
  { name: "Contracting Officer", from: "Contract",    to: "Person",       description: "The person administers the award." },
  { name: "Develop",            from: "Contract",     to: "Technology",   description: "The contract develops the technology." },
  { name: "Apply",              from: "Contract",     to: "Technology",   description: "The contract applies the technology." },
  { name: "Evaluate",           from: "Contract",     to: "Technology",   description: "The contract evaluates the technology." },
  { name: "Mature",             from: "Contract",     to: "Technology",   description: "The contract raises the technology's readiness." },
  { name: "Deliverable",        from: "Contract",     to: "Part",         description: "The part is delivered under the contract." },
  { name: "Component",          from: "Contract",     to: "Part",         description: "The part is a component covered by the contract." },
  { name: "Procurement",        from: "Contract",     to: "Part",         description: "The contract procures the part." },
  { name: "Developer",          from: "Organization", to: "Technology",   description: "The organization builds the technology.", attributes: { "since" => "datetime" } },
  { name: "Funder",             from: "Organization", to: "Technology",   description: "The organization funds the work." },
  { name: "Adopter",            from: "Organization", to: "Technology",   description: "The organization uses the technology." },
  { name: "Licensee",           from: "Organization", to: "Technology",   description: "The organization licensed the technology." }
].freeze

# --- The landscape ---------------------------------------------------------

ENTITIES = {
  "Person" => [
    { "name" => "Wernher von Braun", "first_name" => "Wernher", "last_name" => "von Braun" },
    { "name" => "Kelly Johnson",     "first_name" => "Clarence", "last_name" => "Johnson" },
    { "name" => "Grace Hopper",      "first_name" => "Grace",    "last_name" => "Hopper" },
    { "name" => "Robert Goddard",    "first_name" => "Robert",   "last_name" => "Goddard" },
    { "name" => "Theodore von Karman", "first_name" => "Theodore", "last_name" => "von Karman" }
  ],
  "Organization" => [
    { "name" => "National Aeronautics and Space Administration", "acronym" => "NASA" },
    { "name" => "Defense Advanced Research Projects Agency",     "acronym" => "DARPA" },
    { "name" => "Lockheed Martin",           "acronym" => "LMT" },
    { "name" => "MIT Lincoln Laboratory",    "acronym" => "MIT LL" },
    { "name" => "Rocketdyne",                "acronym" => "RD" },
    { "name" => "Skunk Works",               "acronym" => "ADP" }
  ],
  "Science" => [
    { "name" => "Orbital Mechanics",  "summary" => "The motion of bodies under gravitation." },
    { "name" => "Aerodynamics",       "summary" => "The behaviour of air around moving bodies." },
    { "name" => "Cryogenics",         "summary" => "The behaviour of materials at very low temperature." },
    { "name" => "Electromagnetic Scattering", "summary" => "How surfaces reflect and diffract radio waves." },
    { "name" => "Combustion Physics", "summary" => "The chemistry and dynamics of burning propellant." }
  ],
  "Technology" => [
    { "name" => "Liquid Rocket Propulsion", "summary" => "Thrust from pumped liquid propellant." },
    { "name" => "Stealth Shaping",          "summary" => "Faceted geometry that scatters radar away from its source." },
    { "name" => "Inertial Navigation",      "summary" => "Position from measured acceleration, without external reference." },
    { "name" => "Regenerative Cooling",     "summary" => "Propellant routed through the chamber wall before burning." },
    { "name" => "Pulse-Doppler Radar",      "summary" => "Radar that resolves velocity as well as range." }
  ],
  "Part" => [
    { "name" => "Rocketdyne F-1",           "mass_kg" => 8391.0 },
    { "name" => "Saturn V S-IC Stage",      "mass_kg" => 2280000.0 },
    { "name" => "Apollo Guidance Computer", "mass_kg" => 32.0 },
    { "name" => "SR-71 Airframe",           "mass_kg" => 30600.0 },
    { "name" => "Have Blue Demonstrator",   "mass_kg" => 5670.0 }
  ],
  "Contract" => [
    { "name" => "NAS8-5608", "identifier" => "NAS8-5608", "title" => "Saturn V S-IC stage development",
      "start_date" => "1961-12-15", "end_date" => "1970-06-30", "value_usd" => 1_400_000_000.0 },
    { "name" => "Have Blue", "identifier" => "F33615-76-C-1234", "title" => "Low-observable technology demonstrator",
      "start_date" => "1976-04-01", "end_date" => "1979-12-31", "value_usd" => 43_000_000.0 },
    { "name" => "AGC Development", "identifier" => "NAS9-153", "title" => "Apollo guidance and navigation",
      "start_date" => "1961-08-09", "end_date" => "1972-12-31", "value_usd" => 145_000_000.0 }
  ]
}.freeze

# [ relationship type, from entity name, to entity name, values ]
RELATIONSHIPS = [
  [ "Employment", "Wernher von Braun", "National Aeronautics and Space Administration",
    { "since" => "1960-07-01", "role" => "Director, Marshall Space Flight Center" } ],
  [ "Employment", "Kelly Johnson", "Skunk Works", { "role" => "Chief Engineer" } ],
  [ "Employment", "Grace Hopper", "MIT Lincoln Laboratory", {} ],
  [ "Affiliation", "Theodore von Karman", "National Aeronautics and Space Administration", {} ],
  [ "Friendship", "Wernher von Braun", "Theodore von Karman", {} ],

  [ "Subsidiary", "Skunk Works", "Lockheed Martin", {} ],
  [ "Partnership", "National Aeronautics and Space Administration", "Rocketdyne", {} ],

  [ "Researcher", "Robert Goddard", "Orbital Mechanics", {} ],
  [ "Author", "Theodore von Karman", "Aerodynamics", {} ],
  [ "Contributor", "Grace Hopper", "Electromagnetic Scattering", {} ],

  [ "Enabling Principle", "Combustion Physics", "Liquid Rocket Propulsion", {} ],
  [ "Application", "Orbital Mechanics", "Inertial Navigation", {} ],
  [ "Enabling Principle", "Electromagnetic Scattering", "Stealth Shaping", {} ],
  [ "Application", "Cryogenics", "Regenerative Cooling", {} ],
  [ "Derived From", "Aerodynamics", "Pulse-Doppler Radar", {} ],

  [ "Developer", "Rocketdyne", "Liquid Rocket Propulsion", { "since" => "1955-01-01" } ],
  [ "Developer", "Skunk Works", "Stealth Shaping", { "since" => "1975-01-01" } ],
  [ "Funder", "Defense Advanced Research Projects Agency", "Stealth Shaping", {} ],
  [ "Adopter", "National Aeronautics and Space Administration", "Inertial Navigation", {} ],
  [ "Developer", "MIT Lincoln Laboratory", "Pulse-Doppler Radar", {} ],

  [ "Implementation", "Rocketdyne F-1", "Liquid Rocket Propulsion", {} ],
  [ "Dependency", "Rocketdyne F-1", "Regenerative Cooling", {} ],
  [ "Implementation", "Have Blue Demonstrator", "Stealth Shaping", {} ],
  [ "Implementation", "Apollo Guidance Computer", "Inertial Navigation", {} ],

  [ "Composition", "Rocketdyne F-1", "Saturn V S-IC Stage", { "quantity" => 5 } ],

  [ "Manufacturer", "Rocketdyne F-1", "Rocketdyne", {} ],
  [ "Manufacturer", "SR-71 Airframe", "Skunk Works", {} ],
  [ "Manufacturer", "Have Blue Demonstrator", "Skunk Works", {} ],
  [ "Consumer", "Saturn V S-IC Stage", "National Aeronautics and Space Administration", {} ],
  [ "Demand", "Apollo Guidance Computer", "National Aeronautics and Space Administration", {} ],

  [ "Awardee", "NAS8-5608", "Rocketdyne", {} ],
  [ "Awarding Agency", "NAS8-5608", "National Aeronautics and Space Administration", {} ],
  [ "Deliverable", "NAS8-5608", "Saturn V S-IC Stage", {} ],
  [ "Develop", "NAS8-5608", "Liquid Rocket Propulsion", {} ],
  [ "Principal Investigator", "NAS8-5608", "Wernher von Braun", {} ],

  [ "Awardee", "Have Blue", "Lockheed Martin", {} ],
  [ "Awarding Agency", "Have Blue", "Defense Advanced Research Projects Agency", {} ],
  [ "Deliverable", "Have Blue", "Have Blue Demonstrator", {} ],
  [ "Develop", "Have Blue", "Stealth Shaping", {} ],
  [ "Principal Investigator", "Have Blue", "Kelly Johnson", {} ],

  [ "Awardee", "AGC Development", "MIT Lincoln Laboratory", {} ],
  [ "Awarding Agency", "AGC Development", "National Aeronautics and Space Administration", {} ],
  [ "Deliverable", "AGC Development", "Apollo Guidance Computer", {} ],
  [ "Mature", "AGC Development", "Inertial Navigation", {} ],
  [ "Technical Contact", "AGC Development", "Grace Hopper", {} ]
].freeze

# --- Walking the data ------------------------------------------------------

entity_types = ENTITY_TYPES.to_h do |name, spec|
  type = project.entity_types.find_or_create_by!(name: name) { |t| t.description = spec[:description] }

  spec[:attributes].each do |attribute_name, value_type|
    type.entity_type_attributes.find_or_create_by!(name: attribute_name) do |a|
      a.value_type = value_type
    end
  end

  [ name, type ]
end

relationship_types = RELATIONSHIP_TYPES.to_h do |spec|
  type = project.relationship_types.find_or_create_by!(name: spec[:name]) do |t|
    t.description = RELATIONSHIP_DESCRIPTIONS.fetch(spec[:name])
    t.from_entity_type = entity_types.fetch(spec[:from])
    t.to_entity_type   = entity_types.fetch(spec[:to])
  end

  spec.fetch(:attributes, {}).each do |attribute_name, value_type|
    type.relationship_type_attributes.find_or_create_by!(name: attribute_name) do |a|
      a.value_type = value_type
    end
  end

  [ spec[:name], type ]
end

# Keyed on the name column — every entity has one.
entities = {}

ENTITIES.each do |type_name, records|
  type = entity_types.fetch(type_name)

  records.each do |values|
    entity = project.entities.find_or_create_by!(name: values.fetch("name")) do |e|
      e.entity_type = type
    end

    values.except("name").each do |attribute_name, raw|
      attribute = type.entity_type_attributes.find_by!(name: attribute_name)
      record = EntityAttributeValue.find_or_initialize_by(entity: entity,
                                                          entity_type_attribute: attribute)
      record.value = raw
      record.save!
    end

    entities[values.fetch("name")] = entity
  end
end

RELATIONSHIPS.each do |type_name, from_name, to_name, values|
  type = relationship_types.fetch(type_name)
  from = entities.fetch(from_name)
  to   = entities.fetch(to_name)

  relationship = Relationship.find_or_create_by!(relationship_type: type,
                                                 from_entity: from, to_entity: to)

  values.each do |attribute_name, raw|
    attribute = type.relationship_type_attributes.find_by!(name: attribute_name)
    record = RelationshipTypeValue.find_or_initialize_by(relationship: relationship,
                                                          relationship_type_attribute: attribute)
    record.value = raw
    record.save!
  end
end

puts "Seeded F-DoD: #{project.entity_types.count} entity types, " \
     "#{project.relationship_types.count} relationship types, " \
     "#{project.entities.count} entities, #{project.relationships.count} relationships."
