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
        name: "National Aeronautics and Space Administration",
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
      od.confidence_tenths = d[:confidence_tenths]
      od.additional_attributes = d[:additional_attributes]
      od.source_processing_report = report
    end

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
