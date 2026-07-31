# Development login. Idempotent — re-running seeds will not duplicate the user
# or reset an existing password. Never seeded in production.
if Rails.env.local?
  User.find_or_create_by!(email: "admin@example.com") do |user|
    user.password = "Password1"
  end
end

person_types = {
  "Mathematician"      => { description: "Researcher in mathematics.",       keys: [ "field", "institution" ] },
  "Engineer"           => { description: "Designs and builds systems.",      keys: [ "specialty", "company" ] },
  "Computer Scientist" => { description: "Works in computing research.",     keys: [ "field", "institution" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = PersonType.find_or_create_by!(name: name) do |pt|
    pt.description = attrs[:description]
    pt.additional_attribute_keys = attrs[:keys]
  end
end

skills = [
  { name: "Summarize",  purpose: "Condense a long document into a short brief." },
  { name: "Translate",  purpose: "Translate text from one language to another." }
]

skills.each do |attrs|
  skill = Skill.find_or_create_by!(name: attrs[:name]) do |s|
    s.purpose = attrs[:purpose]
  end

  next if skill.skill_revisions.any?

  SkillRevision.create!(skill: skill, content: "Initial draft of #{skill.name}.")
end

# "Pull Organization Names" carries real prompt content rather than a stub
# draft. A new revision is added only when the content below actually changes,
# so re-running seeds is idempotent.
pull_organization_names_content = <<~MARKDOWN.strip
  Parse the entire website. Pull out Organization names. And create Organizations from those that you find.

  For every Organization, also determine its acronym or initialism — for example
  NASA for "National Aeronautics and Space Administration". Use the acronym the
  source states. If the source does not state one but the organization has a
  well-established acronym you know, use that. Leave it blank when you are not
  confident; do not invent one. Pass it as the `acronym` argument of the
  upsert organization tool, not inside additional_attributes.
MARKDOWN

pull_organization_names = Skill.find_or_create_by!(name: "Pull Organization Names") do |s|
  s.purpose = "Read a website and pull all orgs out."
end

if pull_organization_names.skill_revisions.order(:sequence).last&.content != pull_organization_names_content
  SkillRevision.create!(skill: pull_organization_names, content: pull_organization_names_content)
end

# Applicability statements — what triage reads to decide which skills are worth
# calling on a page. Backfilled here rather than in the migration because they
# are editorial content, not schema. Only written when currently blank, so a
# statement edited in the UI survives re-seeding.
skill_applicability = {
  "Summarize" =>
    "Any page with a substantial body of prose worth condensing — articles, " \
    "reports, filings, long announcements. Not index pages, link lists, " \
    "directories, or tabular data, which have no narrative to summarize.",
  "Translate" =>
    "Pages whose main content is written in a language other than English. " \
    "Not English-language pages, and not pages that are mostly names, numbers, " \
    "or tables, where there is little language to translate.",
  "LinkedIn-Person" =>
    "LinkedIn profile pages for an individual person, showing a name and an " \
    "employment history. Not LinkedIn company pages, job postings, search " \
    "results, or feed pages, and not profile pages on other sites.",
  "Acquisition News" =>
    "News articles and press releases announcing that one company acquired, " \
    "merged with, or bought a stake in another. Look for language about a " \
    "deal between two named companies. Not general business news, not " \
    "earnings coverage, not product announcements, not exhibitor or member " \
    "directories, which name many companies but describe no transaction.",
  "Pull Organization Names" =>
    "Pages that name many organizations — exhibitor lists, member directories, " \
    "sponsor pages, attendee lists, supplier indexes, conference programs. " \
    "Best on pages where organizations are the subject rather than mentioned " \
    "in passing. Not pages about a single company, and not prose articles, " \
    "where a general extraction pulls mostly noise."
}

skill_applicability.each do |name, statement|
  skill = Skill.find_by(name: name)
  next if skill.nil? || skill.applicability.present?

  skill.update!(applicability: statement)
end

# Mark the Summarize skill as promotable so `rails fixtures:promote` has
# something to materialize into a fixture on a fresh dev DB.
Skill.where(name: "Summarize").update_all(is_promotable: true, is_fixtured: false)

# A handful of seed sources are marked promotable so the fixture-promotion
# flow is demoable end-to-end out of the box.
Source.where(url: [
  "https://en.wikipedia.org/wiki/Ada_Lovelace",
  "https://en.wikipedia.org/wiki/NASA"
]).update_all(is_promotable: true, is_fixtured: false)

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

organization_types = {
  "Corporation"        => { description: "A legally incorporated business entity.",  keys: [ "industry", "headquarters" ] },
  "Technology Company" => { description: "Corporation in the tech industry.",        keys: [ "industry", "headquarters", "ticker" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = OrganizationType.find_or_create_by!(name: name) do |ot|
    ot.description = attrs[:description]
    ot.additional_attribute_keys = attrs[:keys]
  end
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

facility_types = {
  "Office Building" => { description: "Commercial office tower.",        keys: [ "floors", "year_built" ] },
  "Government"      => { description: "Government-operated facility.",   keys: [ "agency", "year_built" ] },
  "Research Lab"    => { description: "Scientific research campus.",     keys: [ "discipline", "year_built" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = FacilityType.find_or_create_by!(name: name) do |ft|
    ft.description = attrs[:description]
    ft.additional_attribute_keys = attrs[:keys]
  end
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

person_organization_types = {
  "Affiliation" => { description: "General affiliation between a person and an organization.", keys: [ "role" ] },
  "Employment"  => { description: "Person was employed by the organization.",                  keys: [ "title", "department" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = PersonOrganizationType.find_or_create_by!(name: name) do |pot|
    pot.description = attrs[:description]
    pot.additional_attribute_keys = attrs[:keys]
  end
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
person_person_types = {
  "Marriage"   => { description: "Spousal relationship.",     keys: [ "since" ] },
  "Friendship" => { description: "Close personal friendship.", keys: [] },
  "Family"     => { description: "Familial relationship.",    keys: [ "kind" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = PersonPersonType.find_or_create_by!(name: name) do |pt|
    pt.description = attrs[:description]
    pt.additional_attribute_keys = attrs[:keys]
  end
end

organization_organization_types = {
  "Partnership" => { description: "Business partnership between two organizations.", keys: [ "since", "scope" ] },
  "Subsidiary"  => { description: "One organization is a subsidiary of the other.",  keys: [] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = OrganizationOrganizationType.find_or_create_by!(name: name) do |ot|
    ot.description = attrs[:description]
    ot.additional_attribute_keys = attrs[:keys]
  end
end

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

part_types = {
  "Component"    => { description: "An atomic part used inside larger assemblies.", keys: [ "material", "manufacturer_part_number" ] },
  "Assembly"     => { description: "A collection of parts assembled into a unit.",  keys: [ "manufacturer_part_number" ] },
  "Raw Material" => { description: "A bulk input not yet assembled.",               keys: [ "form" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = PartType.find_or_create_by!(name: name) do |pt|
    pt.description = attrs[:description]
    pt.additional_attribute_keys = attrs[:keys]
  end
end

part_organization_types = {
  "Manufacturer" => { description: "Organization manufactures the part.", keys: [ "since", "factory" ] },
  "Consumer"     => { description: "Organization uses or buys the part.", keys: [ "since" ] },
  "Demand"       => { description: "Organization has signaled demand for the part.", keys: [ "quantity_per_year" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = PartOrganizationType.find_or_create_by!(name: name) do |pot|
    pot.description = attrs[:description]
    pot.additional_attribute_keys = attrs[:keys]
  end
end

part_part_types = {
  "Composition" => { description: "Part B is a component of Part A.", keys: [ "quantity" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = PartPartType.find_or_create_by!(name: name) do |ppt|
    ppt.description = attrs[:description]
    ppt.additional_attribute_keys = attrs[:keys]
  end
end

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

# Research starting points — URLs the system should poll on a schedule to
# kick off research. Wiring is added later; for now we just seed a few.
[
  { url: "https://en.wikipedia.org/wiki/Special:RecentChanges", frequency: "four_times_daily",
    description: "Wikipedia recent changes — high-churn sample feed.",
    is_enabled: true,  last_run_at: 2.hours.ago },
  { url: "https://news.ycombinator.com/",                       frequency: "daily",
    description: "Hacker News front page.",
    is_enabled: true,  last_run_at: 1.day.ago },
  { url: "https://www.nasa.gov/news-release/",                  frequency: "weekly",
    description: "NASA news releases.",
    is_enabled: true,  last_run_at: nil },
  { url: "https://www.federalregister.gov/documents/current",   frequency: "monthly",
    description: "U.S. Federal Register, current documents.",
    is_enabled: false, last_run_at: nil },
  { url: "https://example.com/one-time-report",                 frequency: "one_off",
    description: "Stand-in for a single-shot research target.",
    is_enabled: true,  last_run_at: nil }
].each do |attrs|
  ResearchStartingPoint.find_or_create_by!(url: attrs[:url]) do |rsp|
    rsp.frequency   = attrs[:frequency]
    rsp.description = attrs[:description]
    rsp.is_enabled  = attrs[:is_enabled]
    rsp.last_run_at = attrs[:last_run_at]
  end
end

# A fetched source with a real zipped payload attached, so the Source Data
# table on the source show page — and its "Extract links" action — can be
# exercised in the browser without hitting the network.
link_sample_html = <<~HTML
  <html>
    <head><title>Link sample</title></head>
    <body>
      <a href="/about">About (relative, internal)</a>
      <a href="https://www.nasa.gov/about/">Absolute internal</a>
      <a href="/about#team">Duplicate of /about once the fragment is stripped</a>
      <a href="https://en.wikipedia.org/wiki/Apollo_Guidance_Computer">Wikipedia (external)</a>
      <a href="https://www.federalregister.gov/documents/current">Federal Register (external)</a>
      <a href="#skip-me">Fragment only — skipped</a>
      <a href="mailto:someone@example.com">mailto — skipped</a>
    </body>
  </html>
HTML

link_sample_source = Source.find_or_create_by!(url: "https://www.nasa.gov/news-release/") do |s|
  s.description = "Seeded page with a mix of internal and external links."
end
link_sample_source.update!(status: "complete") unless link_sample_source.status == "complete"

if link_sample_source.source_data.none?
  buffer = Zip::OutputStream.write_buffer do |zos|
    zos.put_next_entry("link-sample.html")
    zos.write(link_sample_html)
  end
  buffer.rewind

  SourceDatum.create!(
    source: link_sample_source,
    content_type: "application/zip",
    data: buffer.read
  )
end

# A small slice of the page-link graph, so the source show page has something
# in its "Links from" / "Links to" sections and its parent-source row without
# having to run a crawl first. Mirrors what extraction would produce.
link_sample_children = [
  { url: "https://www.nasa.gov/about",  description: "About NASA — discovered from the news release index." },
  { url: "https://www.nasa.gov/about/", description: "About NASA (trailing slash variant)." }
].map do |attrs|
  child = Source.find_or_create_by!(url: attrs[:url]) do |s|
    s.description   = attrs[:description]
    s.parent_source = link_sample_source
  end
  SourceLink.record(from: link_sample_source, to: child)
  child
end

# The Apollo source is linked to from the sample page but was seeded
# independently, so it keeps its own (absent) parentage — the case where an
# edge exists without the link having created the target.
SourceLink.record(from: link_sample_source, to: apollo_source)

# And a link back the other way, so at least one source shows both inbound and
# outbound edges.
SourceLink.record(from: link_sample_children.first, to: link_sample_source)

