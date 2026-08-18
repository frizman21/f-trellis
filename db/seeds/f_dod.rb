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
    description: "A named individual.",
    attributes: { "first_name" => "string", "last_name" => "string" }
  },
  "Organization" => {
    description: "A company, agency, laboratory or institution.",
    attributes: { "acronym" => "string" }
  },
  "Science" => {
    description: "A body of knowledge: a field, a principle, a law, an effect.",
    attributes: { "summary" => "string" }
  },
  "Technology" => {
    description: "An engineered capability: a method, a process, a material.",
    attributes: { "summary" => "string" }
  },
  "Part" => {
    description: "A concrete artefact — a built thing with specifications.",
    attributes: { "mass_kg" => "float" }
  },
  "Contract" => {
    description: "An award: who is paid, by whom, to do what.",
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

RELATIONSHIP_TYPES = [
  { name: "Employment",         from: "Person",       to: "Organization", description: "The person is employed by the organization.", attributes: { "since" => "datetime", "role" => "string" } },
  { name: "Affiliation",        from: "Person",       to: "Organization", description: "A looser association than employment." },
  { name: "Marriage",           from: "Person",       to: "Person",       description: "The two people are married." },
  { name: "Friendship",         from: "Person",       to: "Person",       description: "The two people are known associates." },
  { name: "Family",             from: "Person",       to: "Person",       description: "The two people are related." },
  { name: "Partnership",        from: "Organization", to: "Organization", description: "The two organizations work together." },
  { name: "Subsidiary",         from: "Organization", to: "Organization", description: "The first is owned by the second." },
  { name: "Manufacturer",       from: "Part",         to: "Organization", description: "The organization builds the part." },
  { name: "Consumer",           from: "Part",         to: "Organization", description: "The organization uses the part." },
  { name: "Demand",             from: "Part",         to: "Organization", description: "The organization wants the part built." },
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
  { name: "Awardee",            from: "Contract",     to: "Organization", description: "The organization holds the contract." },
  { name: "Awarding Agency",    from: "Contract",     to: "Organization", description: "The organization awarded the contract." },
  { name: "Subcontractor",      from: "Contract",     to: "Organization", description: "The organization works under the contract." },
  { name: "Research Institution", from: "Contract",   to: "Organization", description: "The institution performs research under the contract." },
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
    t.description = spec[:description]
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
