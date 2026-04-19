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
