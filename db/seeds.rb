person_types = {
  "Mathematician" => { description: "Researcher in mathematics.",          keys: [ "field", "institution" ] },
  "Engineer"      => { description: "Designs and builds systems.",         keys: [ "specialty", "company" ] },
  "Computer Scientist" => { description: "Works in computing research.",   keys: [ "field", "institution" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = PersonType.find_or_create_by!(name: name) do |pt|
    pt.description = attrs[:description]
    pt.additional_attribute_keys = attrs[:keys]
  end
end

people = [
  {
    first_name: "Ada", last_name: "Lovelace",
    as_of: Time.zone.parse("1843-10-01"), confidence_tenths: 1000,
    additional_attributes: { "field" => "Analytical Engine", "institution" => "Independent" },
    types: [ "Mathematician", "Computer Scientist" ]
  },
  {
    first_name: "Alan", last_name: "Turing",
    as_of: Time.zone.parse("1936-01-01"), confidence_tenths: 1000,
    additional_attributes: { "field" => "Computability", "institution" => "University of Cambridge" },
    types: [ "Mathematician", "Computer Scientist" ]
  },
  {
    first_name: "Grace", last_name: "Hopper",
    as_of: Time.zone.parse("1944-06-01"), confidence_tenths: 1000,
    additional_attributes: { "specialty" => "Compilers", "company" => "U.S. Navy" },
    types: [ "Computer Scientist", "Engineer" ]
  },
  {
    first_name: "Linus", last_name: "Torvalds",
    as_of: Time.zone.parse("1991-08-25"), confidence_tenths: 950,
    additional_attributes: { "specialty" => "Operating Systems", "company" => "Linux Foundation" },
    types: [ "Engineer" ]
  },
  {
    first_name: "Margaret", last_name: "Hamilton",
    as_of: Time.zone.parse("1969-07-20"), confidence_tenths: 900,
    additional_attributes: { "specialty" => "Flight Software", "company" => "MIT" },
    types: [ "Engineer", "Computer Scientist" ]
  }
]

people.each do |attrs|
  types = attrs.delete(:types)

  detail = PersonDetail.find_by(first_name: attrs[:first_name], last_name: attrs[:last_name])

  if detail.nil?
    person = Person.create!
    detail = PersonDetail.create!(attrs.merge(person: person))
  end

  detail.person_types = types.map { |name| person_types.fetch(name) }
  detail.person.update!(current_detail: detail) if detail.person.current_detail_id.nil?
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

source = Source.find_or_create_by!(url: "https://example.com/ada-lovelace-notes.pdf") do |s|
  s.description = "Example source document for seeding."
end

revision = Skill.find_by(name: "Summarize")&.skill_revisions&.first
if revision && !SourceProcessingReport.exists?(source: source, skill_revision: revision)
  SourceProcessingReport.create!(
    source: source,
    skill_revision: revision,
    facts: { "subject" => "Ada Lovelace", "mentioned_people" => [ "Charles Babbage" ], "pages" => 12 }
  )
end
