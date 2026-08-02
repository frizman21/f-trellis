# Knowledge base content — tier 1 entities, their detail records, and the
# relationships between them. Demo data only.
#
# Loaded from db/seeds.rb, and only when knowledge base seeding is enabled —
# see the SEED_KNOWLEDGE_BASE guard there. Not meant to be run on its own.
#
# The type taxonomies this content hangs off are seeded by db/seeds.rb before
# this file loads, so they are looked up here rather than created.

person_types                    = PersonType.all.index_by(&:name)
organization_types              = OrganizationType.all.index_by(&:name)
facility_types                  = FacilityType.all.index_by(&:name)
person_organization_types       = PersonOrganizationType.all.index_by(&:name)
person_person_types             = PersonPersonType.all.index_by(&:name)
organization_organization_types = OrganizationOrganizationType.all.index_by(&:name)
part_types                      = PartType.all.index_by(&:name)
part_organization_types         = PartOrganizationType.all.index_by(&:name)
part_part_types                 = PartPartType.all.index_by(&:name)

summarize_revision = Skill.find_by(name: "Summarize").skill_revisions.first

people_entries = [
  {
    types: [ "Mathematician", "Computer Scientist" ],
    details: [
      {
        first_name: "Augusta Ada", last_name: "Byron",
        as_of: Time.zone.parse("1815-12-10"), confidence_tenths: 700,
        additional_attributes: { "field" => "Mathematics", "institution" => "Home study" },
        source_url: "https://en.wikipedia.org/wiki/Ada_Lovelace",
        source_description: "Wikipedia: Ada Lovelace."
      },
      {
        first_name: "Ada", last_name: "Lovelace",
        as_of: Time.zone.parse("1843-10-01"), confidence_tenths: 1000,
        additional_attributes: { "field" => "Analytical Engine", "institution" => "Independent" },
        source_url: "https://en.wikipedia.org/wiki/Note_G",
        source_description: "Wikipedia: Note G (Ada Lovelace's algorithm for the Analytical Engine)."
      }
    ]
  },
  {
    types: [ "Mathematician", "Computer Scientist" ],
    details: [
      {
        first_name: "Alan M.", last_name: "Turing",
        as_of: Time.zone.parse("1936-11-12"), confidence_tenths: 950,
        additional_attributes: { "field" => "Computability", "institution" => "Cambridge" },
        source_url: "https://en.wikipedia.org/wiki/Turing%27s_proof",
        source_description: "Wikipedia: Turing's proof (On Computable Numbers, 1936)."
      },
      {
        first_name: "Alan", last_name: "Turing",
        as_of: Time.zone.parse("1950-10-01"), confidence_tenths: 1000,
        additional_attributes: { "field" => "Artificial Intelligence", "institution" => "University of Manchester" },
        source_url: "https://en.wikipedia.org/wiki/Computing_Machinery_and_Intelligence",
        source_description: "Wikipedia: Computing Machinery and Intelligence."
      }
    ]
  },
  {
    types: [ "Computer Scientist", "Engineer" ],
    details: [
      {
        first_name: "Grace M.", last_name: "Hopper",
        as_of: Time.zone.parse("1944-06-01"), confidence_tenths: 900,
        additional_attributes: { "specialty" => "Mark I programming", "company" => "U.S. Navy" },
        source_url: "https://en.wikipedia.org/wiki/Harvard_Mark_I",
        source_description: "Wikipedia: Harvard Mark I."
      },
      {
        first_name: "Grace", last_name: "Hopper",
        as_of: Time.zone.parse("1959-04-01"), confidence_tenths: 1000,
        additional_attributes: { "specialty" => "Compilers", "company" => "U.S. Navy" },
        source_url: "https://en.wikipedia.org/wiki/COBOL",
        source_description: "Wikipedia: COBOL."
      }
    ]
  },
  {
    types: [ "Engineer" ],
    details: [
      {
        first_name: "Linus", last_name: "Torvalds",
        as_of: Time.zone.parse("1991-08-25"), confidence_tenths: 950,
        additional_attributes: { "specialty" => "Operating Systems", "company" => "University of Helsinki" },
        source_url: "https://en.wikipedia.org/wiki/History_of_Linux",
        source_description: "Wikipedia: History of Linux."
      },
      {
        first_name: "Linus", last_name: "Torvalds",
        as_of: Time.zone.parse("2005-04-07"), confidence_tenths: 1000,
        additional_attributes: { "specialty" => "Version Control", "company" => "Linux Foundation" },
        source_url: "https://en.wikipedia.org/wiki/Git",
        source_description: "Wikipedia: Git."
      }
    ]
  },
  {
    types: [ "Engineer", "Computer Scientist" ],
    details: [
      {
        first_name: "Margaret", last_name: "Hamilton",
        as_of: Time.zone.parse("1965-01-01"), confidence_tenths: 850,
        additional_attributes: { "specialty" => "Flight Software", "company" => "MIT Instrumentation Lab" },
        source_url: "https://en.wikipedia.org/wiki/Apollo_Guidance_Computer",
        source_description: "Wikipedia: Apollo Guidance Computer."
      },
      {
        first_name: "Margaret H.", last_name: "Hamilton",
        as_of: Time.zone.parse("1969-07-20"), confidence_tenths: 1000,
        additional_attributes: { "specialty" => "Flight Software", "company" => "MIT" },
        source_url: "https://en.wikipedia.org/wiki/Margaret_Hamilton_(software_engineer)",
        source_description: "Wikipedia: Margaret Hamilton (software engineer)."
      }
    ]
  }
]

people_entries.each do |entry|
  existing_detail = entry[:details]
    .map { |d| PersonDetail.find_by(first_name: d[:first_name], last_name: d[:last_name], as_of: d[:as_of]) }
    .find(&:present?)

  person = existing_detail&.person || Person.create!

  entry[:details].each do |d|
    source = Source.find_or_create_by!(url: d[:source_url]) do |s|
      s.description = d[:source_description]
    end

    report = SourceProcessingReport.find_or_create_by!(source: source, skill_revision: summarize_revision) do |r|
      r.facts = {
        "first_name" => d[:first_name],
        "last_name" => d[:last_name],
        "confidence_tenths" => d[:confidence_tenths],
        "additional_attributes" => d[:additional_attributes]
      }
    end

    detail = PersonDetail.find_or_create_by!(
      person: person,
      first_name: d[:first_name],
      last_name: d[:last_name],
      as_of: d[:as_of]
    ) do |pd|
      pd.confidence_tenths = d[:confidence_tenths]
      pd.additional_attributes = d[:additional_attributes]
      pd.source_processing_report = report
    end

    detail.person_types = entry[:types].map { |n| person_types.fetch(n) }
  end

  latest = entry[:details].max_by { |d| d[:as_of] }
  latest_detail = PersonDetail.find_by!(
    person: person,
    first_name: latest[:first_name],
    last_name: latest[:last_name],
    as_of: latest[:as_of]
  )
  person.update!(current_detail: latest_detail) unless person.current_detail_id == latest_detail.id
end

organization_entries = [
  {
    types: [ "Corporation", "Technology Company" ],
    details: [
      {
        name: "Facebook, Inc.",
        as_of: Time.zone.parse("2004-02-04"), confidence_tenths: 950,
        additional_attributes: { "industry" => "Social Media", "headquarters" => "Cambridge, MA", "ticker" => "FB" },
        source_url: "https://en.wikipedia.org/wiki/History_of_Facebook",
        source_description: "Wikipedia: History of Facebook."
      },
      {
        name: "Meta Platforms, Inc.",
        as_of: Time.zone.parse("2021-10-28"), confidence_tenths: 1000,
        additional_attributes: { "industry" => "Technology", "headquarters" => "Menlo Park, CA", "ticker" => "META" },
        source_url: "https://en.wikipedia.org/wiki/Meta_Platforms",
        source_description: "Wikipedia: Meta Platforms."
      }
    ]
  },
  {
    types: [ "Corporation", "Technology Company" ],
    details: [
      {
        name: "Google Inc.",
        as_of: Time.zone.parse("1998-09-04"), confidence_tenths: 950,
        additional_attributes: { "industry" => "Internet", "headquarters" => "Menlo Park, CA", "ticker" => "GOOG" },
        source_url: "https://en.wikipedia.org/wiki/Google",
        source_description: "Wikipedia: Google."
      },
      {
        name: "Alphabet Inc.",
        as_of: Time.zone.parse("2015-10-02"), confidence_tenths: 1000,
        additional_attributes: { "industry" => "Technology", "headquarters" => "Mountain View, CA", "ticker" => "GOOGL" },
        source_url: "https://en.wikipedia.org/wiki/Alphabet_Inc.",
        source_description: "Wikipedia: Alphabet Inc."
      }
    ]
  },
  {
    types: [ "Corporation" ],
    details: [
      {
        name: "National Aeronautics and Space Administration", acronym: "NASA",
        as_of: Time.zone.parse("1958-07-29"), confidence_tenths: 1000,
        additional_attributes: { "industry" => "Aerospace", "headquarters" => "Washington, D.C." },
        source_url: "https://en.wikipedia.org/wiki/NASA",
        source_description: "Wikipedia: NASA."
      }
    ]
  }
]

organization_entries.each do |entry|
  existing_detail = entry[:details]
    .map { |d| OrganizationDetail.find_by(name: d[:name], as_of: d[:as_of]) }
    .find(&:present?)

  organization = existing_detail&.organization || Organization.create!

  entry[:details].each do |d|
    source = Source.find_or_create_by!(url: d[:source_url]) do |s|
      s.description = d[:source_description]
    end

    report = SourceProcessingReport.find_or_create_by!(source: source, skill_revision: summarize_revision) do |r|
      r.facts = {
        "name" => d[:name],
        "confidence_tenths" => d[:confidence_tenths],
        "additional_attributes" => d[:additional_attributes]
      }
    end

    detail = OrganizationDetail.find_or_create_by!(
      organization: organization,
      name: d[:name],
      as_of: d[:as_of]
    ) do |od|
      od.acronym = d[:acronym]
      od.confidence_tenths = d[:confidence_tenths]
      od.additional_attributes = d[:additional_attributes]
      od.source_processing_report = report
    end

    # Backfills acronyms onto details seeded before the column existed.
    detail.update!(acronym: d[:acronym]) if detail.acronym != d[:acronym]

    detail.organization_types = entry[:types].map { |n| organization_types.fetch(n) }
  end

  latest = entry[:details].max_by { |d| d[:as_of] }
  latest_detail = OrganizationDetail.find_by!(
    organization: organization,
    name: latest[:name],
    as_of: latest[:as_of]
  )
  organization.update!(current_detail: latest_detail) unless organization.current_detail_id == latest_detail.id
end

facility_entries = [
  {
    types: [ "Office Building" ],
    details: [
      {
        address: "350 Fifth Avenue, New York, NY 10118",
        as_of: Time.zone.parse("1931-05-01"), confidence_tenths: 1000,
        additional_attributes: { "floors" => "102", "year_built" => "1931" },
        source_url: "https://en.wikipedia.org/wiki/Empire_State_Building",
        source_description: "Wikipedia: Empire State Building."
      },
      {
        address: "20 W 34th St, New York, NY 10001",
        as_of: Time.zone.parse("2019-01-01"), confidence_tenths: 900,
        additional_attributes: { "floors" => "102", "year_built" => "1931", "renovated" => "2019" },
        source_url: "https://en.wikipedia.org/wiki/Empire_State_Building_renovation",
        source_description: "Wikipedia: Empire State Building renovation (informal)."
      }
    ]
  },
  {
    types: [ "Government" ],
    details: [
      {
        address: "1000 Defense Pentagon, Washington, DC 20301",
        as_of: Time.zone.parse("1943-01-15"), confidence_tenths: 1000,
        additional_attributes: { "agency" => "U.S. Department of Defense", "year_built" => "1943" },
        source_url: "https://en.wikipedia.org/wiki/The_Pentagon",
        source_description: "Wikipedia: The Pentagon."
      }
    ]
  },
  {
    types: [ "Research Lab" ],
    details: [
      {
        address: "Espl. des Particules 1, 1211 Meyrin, Switzerland",
        as_of: Time.zone.parse("1954-09-29"), confidence_tenths: 950,
        additional_attributes: { "discipline" => "Particle Physics", "year_built" => "1954" },
        source_url: "https://en.wikipedia.org/wiki/CERN",
        source_description: "Wikipedia: CERN."
      },
      {
        address: "Espl. des Particules 1, 1211 Meyrin, Switzerland",
        as_of: Time.zone.parse("2008-09-10"), confidence_tenths: 1000,
        additional_attributes: { "discipline" => "Particle Physics", "year_built" => "1954", "notable_facility" => "Large Hadron Collider" },
        source_url: "https://en.wikipedia.org/wiki/Large_Hadron_Collider",
        source_description: "Wikipedia: Large Hadron Collider."
      }
    ]
  }
]

facility_entries.each do |entry|
  existing_detail = entry[:details]
    .map { |d| FacilityDetail.find_by(address: d[:address], as_of: d[:as_of]) }
    .find(&:present?)

  facility = existing_detail&.facility || Facility.create!

  entry[:details].each do |d|
    source = Source.find_or_create_by!(url: d[:source_url]) do |s|
      s.description = d[:source_description]
    end

    report = SourceProcessingReport.find_or_create_by!(source: source, skill_revision: summarize_revision) do |r|
      r.facts = {
        "address" => d[:address],
        "confidence_tenths" => d[:confidence_tenths],
        "additional_attributes" => d[:additional_attributes]
      }
    end

    detail = FacilityDetail.find_or_create_by!(
      facility: facility,
      address: d[:address],
      as_of: d[:as_of]
    ) do |fd|
      fd.confidence_tenths = d[:confidence_tenths]
      fd.additional_attributes = d[:additional_attributes]
      fd.source_processing_report = report
    end

    detail.facility_types = entry[:types].map { |n| facility_types.fetch(n) }
  end

  latest = entry[:details].max_by { |d| d[:as_of] }
  latest_detail = FacilityDetail.find_by!(
    facility: facility,
    address: latest[:address],
    as_of: latest[:as_of]
  )
  facility.update!(current_detail: latest_detail) unless facility.current_detail_id == latest_detail.id
end

# Margaret Hamilton ↔ NASA — known historical affiliation.
margaret = PersonDetail.find_by(first_name: "Margaret H.", last_name: "Hamilton")&.person
nasa     = OrganizationDetail.find_by(name: "National Aeronautics and Space Administration")&.organization
nasa_report = SourceProcessingReport.joins(:source).find_by(sources: { url: "https://en.wikipedia.org/wiki/NASA" })

if margaret && nasa && nasa_report
  po = PersonOrganization.find_or_create_by!(person: margaret, organization: nasa)

  detail = po.person_organization_details.find_or_create_by!(as_of: Time.zone.parse("1969-07-20")) do |d|
    d.source_processing_report = nasa_report
    d.confidence_tenths = 1000
    d.additional_attributes = { "role" => "Director, Software Engineering Division", "title" => "Director", "department" => "Software Engineering Division" }
  end

  detail.person_organization_types = [
    person_organization_types.fetch("Affiliation"),
    person_organization_types.fetch("Employment")
  ]

  po.update!(current_detail: detail) unless po.current_detail_id == detail.id
end

# ---------------------------------------------------------------------------
# Synthetic bulk data: ~12 random companies, ~200 random people, and random
# employment relationships between them. Idempotent via a marker source.
# ---------------------------------------------------------------------------
require "faker"
Faker::Config.random = Random.new(20260419)

SYNTHETIC_SOURCE_URL = "synthetic://random-seed"
synthetic_source = Source.find_or_create_by!(url: SYNTHETIC_SOURCE_URL) do |s|
  s.description = "Synthetic seed data — random people, companies, and relationships."
end
synthetic_report = SourceProcessingReport.find_or_create_by!(
  source: synthetic_source,
  skill_revision: summarize_revision
) do |r|
  r.facts = { "synthetic" => true }
end

# Initials of the significant words in a company name — "Kohler, Predovic and
# Sons" => "KPS". Used to give synthetic organizations a plausible acronym so
# the acronym column and acronym search have data to exercise.
def synthetic_acronym(name)
  initials = name.to_s.scan(/[A-Za-z][A-Za-z'-]*/)
                 .reject { |w| %w[and the of for a an].include?(w.downcase) }
                 .map { |w| w[0].upcase }
                 .join
  initials.length.between?(2, 5) ? initials : nil
end

corporation_type = organization_types.fetch("Corporation")
synthetic_org_count = synthetic_report.organization_details.count

(12 - synthetic_org_count).clamp(0, 12).times do
  organization = Organization.create!
  name = Faker::Company.unique.name
  detail = OrganizationDetail.create!(
    organization: organization,
    name: name,
    acronym: synthetic_acronym(name),
    as_of: Time.zone.now,
    confidence_tenths: 800,
    additional_attributes: {
      "industry"     => Faker::Company.industry,
      "headquarters" => "#{Faker::Address.city}, #{Faker::Address.state_abbr}"
    },
    source_processing_report: synthetic_report
  )
  detail.organization_types = [ corporation_type ]
  organization.update!(current_detail: detail)
end

# Backfills synthetic organizations created before the acronym column existed.
synthetic_report.organization_details.where(acronym: nil).find_each do |detail|
  acronym = synthetic_acronym(detail.name)
  detail.update!(acronym: acronym) if acronym
end

person_type_pool =[ person_types.fetch("Engineer"), person_types.fetch("Computer Scientist"), person_types.fetch("Mathematician") ]
synthetic_person_count = synthetic_report.person_details.count

(200 - synthetic_person_count).clamp(0, 200).times do
  person = Person.create!
  detail = PersonDetail.create!(
    person: person,
    first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    as_of: Time.zone.now,
    confidence_tenths: 700,
    additional_attributes: {
      "field"       => Faker::Job.field,
      "institution" => Faker::Educator.university
    },
    source_processing_report: synthetic_report
  )
  detail.person_types = [ person_type_pool.sample ]
  person.update!(current_detail: detail)
end

employment_type  = person_organization_types.fetch("Employment")
affiliation_type = person_organization_types.fetch("Affiliation")

if PersonOrganization.count < 200
  synthetic_people = Person.where(id: synthetic_report.person_details.select(:person_id)).to_a
  synthetic_orgs   = Organization.where(id: synthetic_report.organization_details.select(:organization_id)).to_a

  rng = Random.new(20260419)
  attempts = 0
  created  = 0
  while created < 250 && attempts < 1500 && synthetic_people.any? && synthetic_orgs.any?
    attempts += 1
    person       = synthetic_people.sample(random: rng)
    organization = synthetic_orgs.sample(random: rng)
    next if PersonOrganization.exists?(person: person, organization: organization)

    po = PersonOrganization.create!(person: person, organization: organization)
    detail = PersonOrganizationDetail.create!(
      person_organization: po,
      as_of: Faker::Date.between(from: 10.years.ago.to_date, to: Date.today),
      confidence_tenths: 900,
      additional_attributes: {
        "title"      => Faker::Job.title,
        "department" => Faker::Commerce.department(max: 1)
      },
      source_processing_report: synthetic_report
    )
    types = [ employment_type ]
    types << affiliation_type if rng.rand < 0.4
    detail.person_organization_types = types
    po.update!(current_detail: detail)
    created += 1
  end
end

# Self-referential types (PersonPerson, OrganizationOrganization)

# Random PersonPerson rows between synthetic people.
if PersonPerson.count < 30
  synthetic_people = Person.where(id: synthetic_report.person_details.select(:person_id)).to_a
  rng = Random.new(20260420)
  attempts = 0
  created = 0
  pp_type_pool = person_person_types.values

  while created < 25 && attempts < 200 && synthetic_people.size >= 2
    attempts += 1
    a, b = synthetic_people.sample(2, random: rng)
    next if a.id == b.id

    pa, pb = [ a.id, b.id ].sort
    next if PersonPerson.exists?(person_a_id: pa, person_b_id: pb)

    pp = PersonPerson.create!(person_a_id: pa, person_b_id: pb)
    detail = PersonPersonDetail.create!(
      person_person: pp,
      as_of: Faker::Date.between(from: 10.years.ago.to_date, to: Date.today),
      confidence_tenths: 850,
      additional_attributes: { "kind" => Faker::Relationship.familial },
      source_processing_report: synthetic_report
    )
    detail.person_person_types = [ pp_type_pool.sample(random: rng) ]
    pp.update!(current_detail: detail)
    created += 1
  end
end

# Random OrganizationOrganization rows between synthetic orgs.
if OrganizationOrganization.count < 8
  synthetic_orgs = Organization.where(id: synthetic_report.organization_details.select(:organization_id)).to_a
  rng = Random.new(20260421)
  attempts = 0
  created = 0
  oo_type_pool = organization_organization_types.values

  while created < 6 && attempts < 100 && synthetic_orgs.size >= 2
    attempts += 1
    a, b = synthetic_orgs.sample(2, random: rng)
    next if a.id == b.id

    oa, ob = [ a.id, b.id ].sort
    next if OrganizationOrganization.exists?(organization_a_id: oa, organization_b_id: ob)

    oo = OrganizationOrganization.create!(organization_a_id: oa, organization_b_id: ob)
    detail = OrganizationOrganizationDetail.create!(
      organization_organization: oo,
      as_of: Faker::Date.between(from: 10.years.ago.to_date, to: Date.today),
      confidence_tenths: 900,
      additional_attributes: { "scope" => Faker::Company.industry },
      source_processing_report: synthetic_report
    )
    detail.organization_organization_types = [ oo_type_pool.sample(random: rng) ]
    oo.update!(current_detail: detail)
    created += 1
  end
end

# ---------------------------------------------------------------------------
# Ensure every Person has at least one PersonPerson edge, and every
# Organization has at least one OrganizationOrganization edge. Pairs
# unconnected entities two-by-two; if a single id is left over, links it to a
# random already-existing peer.
# ---------------------------------------------------------------------------

def ensure_self_relationships(rel_class:, all_ids:, fk_a:, fk_b:, random_seed:, &build_detail)
  connected_ids = (rel_class.distinct.pluck(fk_a) + rel_class.distinct.pluck(fk_b)).uniq.to_set
  needs = all_ids.reject { |id| connected_ids.include?(id) }
  rng = Random.new(random_seed)
  needs = needs.shuffle(random: rng)

  needs.each_slice(2) do |pair|
    if pair.size == 2
      a_id, b_id = pair.minmax
    else
      leftover = pair.first
      partner = (all_ids - [ leftover ]).sample(random: rng)
      next if partner.nil?
      a_id, b_id = [ leftover, partner ].minmax
    end

    next if a_id == b_id
    next if rel_class.exists?(fk_a => a_id, fk_b => b_id)

    rel = rel_class.create!(fk_a => a_id, fk_b => b_id)
    detail = build_detail.call(rel, rng)
    rel.update!(current_detail: detail)
  end
end

ensure_self_relationships(
  rel_class: PersonPerson,
  all_ids: Person.pluck(:id),
  fk_a: :person_a_id,
  fk_b: :person_b_id,
  random_seed: 20260422
) do |rel, rng|
  detail = PersonPersonDetail.create!(
    person_person: rel,
    as_of: Faker::Date.between(from: 10.years.ago.to_date, to: Date.today),
    confidence_tenths: 800,
    additional_attributes: { "kind" => Faker::Relationship.familial },
    source_processing_report: synthetic_report
  )
  detail.person_person_types = [ person_person_types.values.sample(random: rng) ]
  detail
end

ensure_self_relationships(
  rel_class: OrganizationOrganization,
  all_ids: Organization.pluck(:id),
  fk_a: :organization_a_id,
  fk_b: :organization_b_id,
  random_seed: 20260423
) do |rel, rng|
  detail = OrganizationOrganizationDetail.create!(
    organization_organization: rel,
    as_of: Faker::Date.between(from: 10.years.ago.to_date, to: Date.today),
    confidence_tenths: 850,
    additional_attributes: { "scope" => Faker::Company.industry },
    source_processing_report: synthetic_report
  )
  detail.organization_organization_types = [ organization_organization_types.values.sample(random: rng) ]
  detail
end

# ---------------------------------------------------------------------------
# Parts: tier 1 + Part↔Organization + Part↔Part composition.
# ---------------------------------------------------------------------------

# Seeded parts tied to existing Apollo / NASA story.
parts_data = {
  "Apollo Guidance Computer" => {
    types: [ "Assembly" ],
    additional_attributes: { "manufacturer_part_number" => "AGC-Block-II" },
    source_url: "https://en.wikipedia.org/wiki/Apollo_Guidance_Computer"
  },
  "AGC Memory Module" => {
    types: [ "Component" ],
    additional_attributes: { "material" => "Magnetic core rope memory", "manufacturer_part_number" => "AGC-MEM" },
    source_url: "https://en.wikipedia.org/wiki/Apollo_Guidance_Computer"
  },
  "AGC CPU Module" => {
    types: [ "Component" ],
    additional_attributes: { "material" => "RTL flat-pack ICs", "manufacturer_part_number" => "AGC-CPU" },
    source_url: "https://en.wikipedia.org/wiki/Apollo_Guidance_Computer"
  },
  "AGC Power Supply" => {
    types: [ "Component" ],
    additional_attributes: { "manufacturer_part_number" => "AGC-PSU" },
    source_url: "https://en.wikipedia.org/wiki/Apollo_Guidance_Computer"
  }
}

apollo_source = Source.find_or_create_by!(url: "https://en.wikipedia.org/wiki/Apollo_Guidance_Computer") do |s|
  s.description = "Wikipedia: Apollo Guidance Computer."
end
apollo_report = SourceProcessingReport.find_or_create_by!(source: apollo_source, skill_revision: summarize_revision) do |r|
  r.facts = { "subject" => "Apollo Guidance Computer" }
end

parts_by_name = {}
parts_data.each do |name, attrs|
  detail = PartDetail.find_by(name: name)
  if detail.nil?
    part = Part.create!
    detail = PartDetail.create!(
      part: part,
      name: name,
      as_of: Time.zone.parse("1969-07-20"),
      confidence_tenths: 950,
      additional_attributes: attrs[:additional_attributes],
      source_processing_report: apollo_report
    )
  end
  detail.part_types = attrs[:types].map { |t| part_types.fetch(t) }
  detail.part.update!(current_detail: detail) unless detail.part.current_detail_id == detail.id
  parts_by_name[name] = detail.part
end

# NASA is the consumer of the Apollo Guidance Computer.
nasa_org = OrganizationDetail.find_by(name: "National Aeronautics and Space Administration")&.organization
agc_part = parts_by_name["Apollo Guidance Computer"]

if nasa_org && agc_part
  po = PartOrganization.find_or_create_by!(part: agc_part, organization: nasa_org)
  detail = po.part_organization_details.find_or_create_by!(as_of: Time.zone.parse("1966-08-25")) do |d|
    d.source_processing_report = apollo_report
    d.confidence_tenths = 1000
    d.additional_attributes = { "since" => "1966" }
  end
  detail.part_organization_types = [ part_organization_types.fetch("Consumer") ]
  po.update!(current_detail: detail) unless po.current_detail_id == detail.id
end

# Compositional relationships: AGC is composed of memory, CPU, power supply.
[ "AGC Memory Module", "AGC CPU Module", "AGC Power Supply" ].each do |child_name|
  parent = agc_part
  child  = parts_by_name[child_name]
  next unless parent && child

  a_id, b_id = [ parent.id, child.id ].minmax
  pp = PartPart.find_or_create_by!(part_a_id: a_id, part_b_id: b_id)
  detail = pp.part_part_details.find_or_create_by!(as_of: Time.zone.parse("1969-07-20")) do |d|
    d.source_processing_report = apollo_report
    d.confidence_tenths = 950
    d.additional_attributes = { "quantity" => "1", "parent" => parent.id == a_id ? "a" : "b" }
  end
  detail.part_part_types = [ part_part_types.fetch("Composition") ]
  pp.update!(current_detail: detail) unless pp.current_detail_id == detail.id
end

# Ensure every part has at least one Manufacturer organization. Pulls from
# the synthetic Faker companies so we don't accidentally make NASA the
# manufacturer of its own AGC.
manufacturer_type = part_organization_types.fetch("Manufacturer")
synthetic_orgs = Organization.where(id: synthetic_report.organization_details.select(:organization_id)).to_a
mfg_rng = Random.new(20260424)

Part.find_each do |part|
  has_manufacturer = PartOrganizationDetail
    .joins(:part_organization_types, :part_organization)
    .where(part_organizations: { part_id: part.id }, part_organization_types: { id: manufacturer_type.id })
    .exists?
  next if has_manufacturer
  next if synthetic_orgs.empty?

  # Avoid orgs already linked to this part (the unique index forbids duplicate
  # part↔org pairs, and re-using a Consumer org as the Manufacturer would be wrong).
  linked_org_ids = part.part_organizations.pluck(:organization_id)
  candidates = synthetic_orgs.reject { |o| linked_org_ids.include?(o.id) }
  next if candidates.empty?

  org = candidates.sample(random: mfg_rng)
  po = PartOrganization.find_or_create_by!(part: part, organization: org)
  detail = po.part_organization_details.create!(
    as_of: Faker::Date.between(from: 5.years.ago.to_date, to: Date.today),
    confidence_tenths: 800,
    additional_attributes: {
      "since"   => mfg_rng.rand(1990..2024).to_s,
      "factory" => "#{Faker::Address.city}, #{Faker::Address.state_abbr}"
    },
    source_processing_report: synthetic_report
  )
  detail.part_organization_types = [ manufacturer_type ]
  po.update!(current_detail: detail)
end

# Synthetic Chat for the inspection UI. Idempotent via a sentinel content
# string in the user message — re-running seeds will not create duplicates.
seed_chat_marker = "[seed:inspection-demo]"
unless Message.exists?(content: seed_chat_marker)
  demo_model = Model.find_by(provider: "anthropic", model_id: "claude-sonnet-4-5") ||
               Model.find_by(model_id: "gpt-5-nano") ||
               Model.first

  demo_chat = Chat.create!(model: demo_model)
  Message.create!(
    chat: demo_chat,
    role: "user",
    content: seed_chat_marker,
    input_tokens: 8
  )
  Message.create!(
    chat: demo_chat,
    role: "assistant",
    model: demo_model,
    content: "Synthetic reply seeded for the chat inspection UI. Replace by exercising RubyLLM with a real prompt.",
    input_tokens: 8,
    output_tokens: 22
  )
end
