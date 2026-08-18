# Development login. Idempotent — re-running seeds will not duplicate the user
# or reset an existing password. Never seeded in production.
if Rails.env.local?
  User.find_or_create_by!(email: "admin@example.com") do |user|
    user.password = "Password1"
  end

  # A read-only counterpart, so the restriction can be exercised by signing in
  # as it rather than only in the test suite. Reads everything, writes nothing.
  User.find_or_create_by!(email: "readonly@example.com") do |user|
    user.password = "Password1"
    user.read_only = true
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

# A revision records the model it runs on, so the skill page has a model to show
# per revision. Seeded only when the registry has been refreshed — it is
# populated from the providers, not from here — and only onto the newest
# revision, so the older ones keep reading "not recorded" and both states are
# visible on one page.
#
# Also gives the skill the matching preferred_model, since the two are meant to
# agree: the pointer is what the edit form writes, the revision is the history.
seed_skill_model = Model.selectable.first

# So the models page shows both out-of-circulation states without waiting for a
# run to fail. Chosen from models that already carry a capability flag — an
# embedding or audio model nothing would have picked anyway — so seeding this
# never takes a working model away from the rest of the seeds.
Model.current.usable.reject(&:chat_capable?).first(2).each_with_index do |model, index|
  model.update!(index.zero? ? { is_deprecated: true } : { is_disabled: true })
end

if seed_skill_model
  pull_organization_names.update!(preferred_model: seed_skill_model)
  current = pull_organization_names.skill_revisions.order(:sequence).last
  current.update!(model: seed_skill_model) if current && current.model_id.nil?
end

# The skill that reads a product page and fills in the specification structure.
# It deliberately does not list the part types or their units: the upsert_part
# tool puts the live taxonomy in its own description, and repeating it here would
# be a second copy to drift out of date the moment a part type gains a parameter.
pull_part_specifications_content = <<~MARKDOWN.strip
  This page describes one or more products, components or parts. Record each of
  them with the upsert part tool, in a single call.

  For each part:

  - Use the product's own model designation as the name — "Mavic 4 Pro", not
    "the drone". Do not merge variants of a product that have different
    specifications; record them as separate parts.
  - Give every part type that applies. The types decide which specifications can
    be recorded, and most parts are a Physical Part as well as whatever else they
    are.
  - Read the specification table, not the marketing copy. A number in a spec
    table is stated; a number in a headline is often rounded or conditional.
  - Convert each value into the unit the tool declares for that parameter, and
    put the page's own wording in `as_stated`. If the page says "624 g" and the
    parameter is in grams, `as_stated` is still worth giving.
  - Where a page gives a range or a qualified figure ("up to 45 mins", "34
    mins with the standard battery"), record the number and put the
    qualification in `as_stated`.
  - Specifications the taxonomy does not declare go in additional_attributes, not
    into a parameter that looks close enough.

  Set confidence from where the number came: a manufacturer's own spec table is
  near certain, a figure quoted in prose less so, and anything you inferred or
  converted from an ambiguous unit lower still.
MARKDOWN

pull_part_specifications = Skill.find_or_create_by!(name: "Pull Part Specifications") do |s|
  s.purpose = "Read a product page and record each part with its measured specifications."
end

if pull_part_specifications.skill_revisions.order(:sequence).last&.content != pull_part_specifications_content
  SkillRevision.create!(skill: pull_part_specifications, content: pull_part_specifications_content)
end

# The skill that reads a paper — an abstract, a conference paper, a whitepaper —
# and pulls the science and the technology out of it, along with the edges
# between them and the people behind them. A first draft: the wording here is
# expected to be revised against real papers rather than to be right first time.
#
# Like "Pull Part Specifications" it does not restate the taxonomies. The
# upsert tools carry the live science and technology types in their own
# descriptions, and a second copy here would drift the moment a type is added.
read_abstract_content = <<~MARKDOWN.strip
  This page is a research paper, an abstract, or a technical whitepaper. Read it
  for the *knowledge* it reports, not for the document itself. The paper is not
  the finding, and the title is not the name of anything.

  Work in this order. Each step gives the next one the ids it needs.

  ## 1. Name the science

  A **Science** is a body of knowledge: a field, a principle, a law, an effect, a
  phenomenon. Record it with the upsert science tool.

  - Name it as a subject, not as a document — "Magnetohydrodynamics", not "On the
    flow of conducting fluids in a magnetic field".
  - Prefer the established name of the field or effect over the authors' phrasing
    for it. If the paper coins a term for something that already has a name, use
    the established one and put the coined term in `additional_attributes`.
  - Give a one-sentence `summary` in the source's own terms.
  - A paper usually sits in one or two sciences. Recording five is a sign you are
    listing the keywords rather than reading the work.
  - Genuinely new science — an effect the paper is the first to report — is still
    a Science. Record it with lower confidence, not by leaving it out.

  ## 2. Name the technology

  A **Technology** is an engineered capability: a method, a process, a material,
  a class of device, a subsystem. Record it with the upsert technology tool.

  - Name it generically. "Solid-state lithium battery" is a technology;
    "PowerCell 9000" is a product, and a product is a Part.
  - Give a one-sentence `summary` of what it does.
  - A paper about pure science may name no technology at all. That is a valid
    reading — do not invent one to fill the slot.
  - The distinction that matters: a Science is knowledge about how the world
    behaves; a Technology is a way of making the world do something. "Superconductivity"
    is a science. "Superconducting magnet winding" is a technology.

  ## 3. Name the people and the organizations

  Record the authors with the upsert person tool and their affiliations with the
  upsert organization tool, then link each author to their affiliation with the
  link person organization tool. Author lists are the most reliable facts on the
  page — record them at high confidence.

  ## 4. Record the contract, if the source names one

  Award pages, contract announcements and funded-project summaries usually give
  a contract or grant number. Where one is stated, record it with the upsert
  contract tool. The contract is what actually ties a company to the technology
  it is paid to build, so it is worth more than any other single fact on such a
  page.

  - The **identifier** is the contract number, not the project title. Use it
    exactly as written.
  - Give the title, the award value in dollars, and the start and end dates
    where the source states them. Phase, program, solicitation number and
    tracking number go in additional_attributes.
  - **Only record a contract the source names.** A paper that says it was funded
    by an agency, without a number, has no Contract in it. Record the agency's
    involvement with the link organization technology tool as "Funder" instead.

  Then say what the contract covers:

  - **link contract organization** — the awardee company, the awarding agency,
    any subcontractor, any partnered research institution.
  - **link contract person** — the principal investigator and any named
    technical contact. On an award page the PI is the most reliable person on it.
  - **link contract technology** — what the contract is *for*. "Develop" where it
    funds building the technology, "Apply", "Evaluate" or "Mature" otherwise.
  - **link contract part** — only where the contract names a concrete artefact it
    delivers or procures.

  ## 5. Build the relationships

  This is the point of the exercise. A science and a technology recorded with no
  edge between them says almost nothing.

  - **Science ↔ Technology** — link every technology to the science it rests on
    with the link science technology tool. Use "Application" where the technology
    applies the science, "Derived From" where it grew out of work in the field,
    and "Enabling Principle" where the technology could not exist without it.
  - **Person ↔ Science** — link every author to the science they wrote in with
    the link person science tool, as "Author". Add "Researcher" where the paper
    shows the field is their standing work rather than a one-off, and
    "Contributor" where the paper credits them with a specific named
    contribution.
  - **Part ↔ Technology** — only where the paper names a concrete artefact: a
    specific device, instrument, or product it built or tested. Record that
    artefact with the upsert part tool, then link it as "Implementation". A paper
    that describes a method with no built instance has no Part in it, and
    inventing one to hang the technology off is worse than leaving the edge out.
  - **Organization ↔ Technology** — link the organization doing the work to the
    technology with the link organization technology tool, as "Developer". Use
    "Funder" for an agency that paid without a contract number in evidence, and
    "Adopter" or "Licensee" where the source says a company took up or licensed
    someone else's technology. Where you already recorded a contract covering the
    same work, record this edge anyway: it stays true if the contract ends.

  Do not connect a person or an organization to a technology just because they
  share a science. Two projects can both rest on optics and have nothing to do
  with each other, and an edge asserting otherwise is worse than no edge.

  ## Confidence

  Set confidence from what the source actually did with the claim, per link and
  per entity:

  - **900–1000** — stated outright, in the abstract, the results or the author
    list.
  - **700–850** — clearly implied by the paper but never stated in those terms.
  - **400–650** — your inference from domain knowledge the paper assumes. The
    science-to-technology edge is often this: a paper on a battery chemistry
    rarely says "this applies electrochemistry".
  - Below 400, leave it out. A low-confidence edge is still an assertion, and a
    graph full of guesses is harder to use than a sparse one.

  Do not record the paper itself as an entity of any kind. Its identity lives in
  the Source, and every detail you write is already attributed to it.
MARKDOWN

read_abstract = Skill.find_or_create_by!(name: "Read Abstract for Science and Technology") do |s|
  s.purpose = "Read a paper abstract or whitepaper and pull out the science, the technology, " \
              "and the relationships between them and the people behind them."
end

if read_abstract.skill_revisions.order(:sequence).last&.content != read_abstract_content
  SkillRevision.create!(skill: read_abstract, content: read_abstract_content)
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
    "where a general extraction pulls mostly noise.",
  "Read Abstract for Science and Technology" =>
    "Research papers, conference papers, preprints, abstracts and technical " \
    "whitepapers — pages reporting a scientific or engineering finding, with " \
    "an author list, an abstract, or a results section. Not news coverage of " \
    "research, not product pages, not press releases, and not journal or " \
    "conference index pages, which list papers without reporting any of them.",
  "Pull Part Specifications" =>
    "Manufacturer product pages and spec sheets for a physical product — a " \
    "drone, a battery, a motor, a camera payload, a component. Look for a " \
    "specifications table: named measurements with units, such as weight, " \
    "flight time, capacity or power. Not news about a product, not press " \
    "releases, not store listings that give only a price, and not company or " \
    "exhibitor pages, which name products without measuring them."
}

skill_applicability.each do |name, statement|
  skill = Skill.find_by(name: name)
  next if skill.nil? || skill.applicability.present?

  skill.update!(applicability: statement)
end

# URL patterns — where the URL alone settles which skill reads the page, saying
# so costs nothing and beats asking the model. Only the skills whose pages are
# predictable by URL get patterns; the rest route by their statement. Kept
# narrow on purpose: a matching pattern excludes every other skill from the
# page. Written only when currently empty, so edits in the UI survive re-seeding.
skill_url_patterns = {
  "LinkedIn-Person" => [
    'linkedin\.com/in/'
  ],
  "Acquisition News" => [
    'prnewswire\.com/news-releases/',
    'businesswire\.com/news/',
    'globenewswire\.com/news-release/'
  ]
}

skill_url_patterns.each do |name, patterns|
  skill = Skill.find_by(name: name)
  next if skill.nil? || skill.url_patterns.present?

  skill.update!(url_patterns: patterns)
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


# ---------------------------------------------------------------------------
# Type taxonomies.
#
# These are reference data, not knowledge content: every *_types table has its
# own CRUD controller and is user-editable, and the entity forms read from
# them. They are seeded in every environment, including ones where the
# knowledge base below is skipped, so the pickers are never empty.
# ---------------------------------------------------------------------------

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

organization_types = {
  "Corporation"        => { description: "A legally incorporated business entity.",  keys: [ "industry", "headquarters" ] },
  "Technology Company" => { description: "Corporation in the tech industry.",        keys: [ "industry", "headquarters", "ticker" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = OrganizationType.find_or_create_by!(name: name) do |ot|
    ot.description = attrs[:description]
    ot.additional_attribute_keys = attrs[:keys]
  end
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

person_organization_types = {
  "Affiliation" => { description: "General affiliation between a person and an organization.", keys: [ "role" ] },
  "Employment"  => { description: "Person was employed by the organization.",                  keys: [ "title", "department" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = PersonOrganizationType.find_or_create_by!(name: name) do |pot|
    pot.description = attrs[:description]
    pot.additional_attribute_keys = attrs[:keys]
  end
end

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

# What each part type is measured by. `additional_attribute_keys` above stays
# what it was — free-form labels; these are the measured ones, each with the unit
# its values are stored in. A part carries several types, so a drone typed both
# "Physical Part" and "Airframe" is measured by both sets, which is how "all
# physical parts have a weight" is expressed without an inheritance hierarchy.
part_type_parameters = {
  "Physical Part" => {
    description: "Anything with mass and dimensions. Nearly every part is one.",
    parameters: [
      { name: "weight", unit: "g", description: "Mass of the part as shipped, excluding packaging." },
      { name: "length", unit: "mm" },
      { name: "width", unit: "mm" },
      { name: "height", unit: "mm" },
      { name: "material", unit: nil, value_type: "text", description: "Primary material, e.g. carbon fibre." }
    ]
  },
  "Electrical Component" => {
    description: "A part that draws or supplies electrical power.",
    parameters: [
      { name: "max_power", unit: "W", description: "Peak power draw." },
      { name: "operating_voltage", unit: "V" },
      { name: "max_current", unit: "A" }
    ]
  },
  "Battery" => {
    description: "An energy store. Also an electrical component and a physical part.",
    parameters: [
      { name: "capacity", unit: "mAh" },
      { name: "energy", unit: "Wh" },
      { name: "cell_configuration", unit: nil, value_type: "text", description: "e.g. 4S, 6S1P." },
      { name: "charge_time", unit: "min" }
    ]
  },
  "Motor" => {
    description: "A rotating actuator, typically a brushless DC motor on a drone.",
    parameters: [
      { name: "kv_rating", unit: "rpm/V" },
      { name: "max_thrust", unit: "g" },
      { name: "stator_diameter", unit: "mm" }
    ]
  },
  "Camera Payload" => {
    description: "An imaging sensor carried by an aircraft.",
    parameters: [
      { name: "sensor_resolution", unit: "MP" },
      { name: "focal_length", unit: "mm" },
      { name: "aperture", unit: nil, value_type: "text", description: "e.g. f/2.8." },
      { name: "video_resolution", unit: nil, value_type: "text", description: "e.g. 4K/60fps." }
    ]
  },
  "Airframe" => {
    description: "A complete aircraft: the thing a product page is usually about.",
    parameters: [
      { name: "takeoff_weight", unit: "g", description: "Maximum takeoff weight, including payload." },
      { name: "flight_time", unit: "min", description: "Manufacturer-stated maximum hover or flight time." },
      { name: "max_speed", unit: "m/s" },
      { name: "max_range", unit: "km", description: "Maximum transmission or operating range." },
      { name: "wind_resistance", unit: "m/s" },
      { name: "ingress_protection", unit: nil, value_type: "text", description: "IP rating, e.g. IP54." }
    ]
  }
}

part_type_parameters.each do |type_name, attrs|
  type = PartType.find_or_create_by!(name: type_name) do |pt|
    pt.description = attrs[:description]
    pt.additional_attribute_keys = [ "manufacturer_part_number" ]
  end
  part_types[type_name] = type

  attrs[:parameters].each do |parameter|
    # Updated rather than only created, so correcting a unit here corrects it in
    # a dev database that already ran an earlier seed.
    row = type.part_type_parameters.find_or_initialize_by(name: parameter[:name])
    row.update!(unit: parameter[:unit], description: parameter[:description],
                value_type: parameter.fetch(:value_type, "number"))
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

science_types = {
  "Discipline" => { description: "A named field of study — physics, metallurgy, immunology.",
                    keys: [ "parent_field" ] },
  "Principle"  => { description: "A law, effect or theorem a field rests on.",
                    keys: [ "named_after" ] },
  "Phenomenon" => { description: "An observed behaviour a field studies and a technology exploits.",
                    keys: [ "first_observed" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = ScienceType.find_or_create_by!(name: name) do |st|
    st.description = attrs[:description]
    st.additional_attribute_keys = attrs[:keys]
  end
end

technology_types = {
  "Method"      => { description: "A way of doing something — a process, a technique, an algorithm.",
                     keys: [ "maturity" ] },
  "Material"    => { description: "An engineered material with a capability the bulk substance lacks.",
                     keys: [ "maturity" ] },
  "Device"      => { description: "A class of engineered artefact, not a specific product.",
                     keys: [ "maturity" ] },
  "Subsystem"   => { description: "An engineered capability that only exists inside something larger.",
                     keys: [ "maturity", "host_system" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = TechnologyType.find_or_create_by!(name: name) do |tt|
    tt.description = attrs[:description]
    tt.additional_attribute_keys = attrs[:keys]
  end
end

part_technology_types = {
  "Implementation" => { description: "The part is a built instance of the technology.", keys: [ "since" ] },
  "Dependency"     => { description: "The part cannot work without the technology.",    keys: [ "subsystem" ] },
  "Enabler"        => { description: "The part is what made the technology practical.",  keys: [ "since" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = PartTechnologyType.find_or_create_by!(name: name) do |ptt|
    ptt.description = attrs[:description]
    ptt.additional_attribute_keys = attrs[:keys]
  end
end

science_technology_types = {
  "Application"        => { description: "The technology applies the science directly.", keys: [ "since" ] },
  "Derived From"       => { description: "The technology grew out of work in the science.", keys: [ "since" ] },
  "Enabling Principle" => { description: "The science is the principle the technology could not work without.",
                            keys: [] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = ScienceTechnologyType.find_or_create_by!(name: name) do |stt|
    stt.description = attrs[:description]
    stt.additional_attribute_keys = attrs[:keys]
  end
end

person_science_types = {
  "Researcher"  => { description: "The person works in the field.",                keys: [ "institution", "since" ] },
  "Author"      => { description: "The person authored the source's findings in this field.",
                     keys: [ "institution" ] },
  "Contributor" => { description: "The person made a named contribution to the field.",
                     keys: [ "contribution" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = PersonScienceType.find_or_create_by!(name: name) do |pst|
    pst.description = attrs[:description]
    pst.additional_attribute_keys = attrs[:keys]
  end
end

contract_types = {
  "Research Contract"          => { description: "Funds investigation, with knowledge as the deliverable.",
                                    keys: [ "vehicle", "competition" ] },
  "Development Contract"       => { description: "Funds building a thing, with hardware or software as the deliverable.",
                                    keys: [ "vehicle", "competition" ] },
  "Grant"                      => { description: "Funds work without procuring a deliverable for the funder.",
                                    keys: [ "program" ] },
  "Other Transaction Agreement" => { description: "An agreement outside the standard procurement regulations.",
                                     keys: [ "vehicle" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = ContractType.find_or_create_by!(name: name) do |ct|
    ct.description = attrs[:description]
    ct.additional_attribute_keys = attrs[:keys]
  end
end

contract_organization_types = {
  "Awardee"              => { description: "The organization the contract is with.", keys: [ "role" ] },
  "Awarding Agency"      => { description: "The organization paying for the work.",  keys: [ "office" ] },
  "Subcontractor"        => { description: "Works under the awardee on this contract.", keys: [ "scope" ] },
  "Research Institution" => { description: "A university or institute partnered on the contract.",
                              keys: [ "department" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = ContractOrganizationType.find_or_create_by!(name: name) do |cot|
    cot.description = attrs[:description]
    cot.additional_attribute_keys = attrs[:keys]
  end
end

contract_person_types = {
  "Principal Investigator" => { description: "Leads the technical work on the contract.", keys: [ "title" ] },
  "Technical Contact"      => { description: "Named point of contact for the work.",      keys: [ "title" ] },
  "Contracting Officer"    => { description: "Holds the contract on the funder's side.",  keys: [ "office" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = ContractPersonType.find_or_create_by!(name: name) do |cpt|
    cpt.description = attrs[:description]
    cpt.additional_attribute_keys = attrs[:keys]
  end
end

contract_technology_types = {
  "Develop" => { description: "The contract funds building the technology.",     keys: [ "phase" ] },
  "Apply"   => { description: "The contract puts an existing technology to use.", keys: [ "phase" ] },
  "Evaluate" => { description: "The contract funds assessing the technology, not building it.",
                  keys: [ "phase" ] },
  "Mature"  => { description: "The contract funds raising the technology's readiness level.",
                 keys: [ "phase", "target_trl" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = ContractTechnologyType.find_or_create_by!(name: name) do |ctt|
    ctt.description = attrs[:description]
    ctt.additional_attribute_keys = attrs[:keys]
  end
end

contract_part_types = {
  "Deliverable" => { description: "The part is what the contract hands over.", keys: [ "quantity" ] },
  "Component"   => { description: "The part goes into what the contract delivers.", keys: [ "quantity" ] },
  "Procurement" => { description: "The contract buys the part rather than developing it.",
                     keys: [ "quantity", "unit_price_usd" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = ContractPartType.find_or_create_by!(name: name) do |cpt|
    cpt.description = attrs[:description]
    cpt.additional_attribute_keys = attrs[:keys]
  end
end

# The direct organization-to-technology edge, for what a contract cannot say.
# "Developer" overlaps with holding a Develop contract, on purpose: a company
# can build something with no award behind it, and adoption and licensing
# rarely have a contract in our sources at all.
organization_technology_types = {
  "Developer" => { description: "The organization builds the technology.",   keys: [ "since", "maturity" ] },
  "Funder"    => { description: "The organization pays for work on it.",     keys: [ "since" ] },
  "Adopter"   => { description: "The organization uses the technology.",     keys: [ "since" ] },
  "Licensee"  => { description: "The organization licensed the technology from whoever owns it.",
                   keys: [ "since", "licensor" ] }
}.each_with_object({}) do |(name, attrs), memo|
  memo[name] = OrganizationTechnologyType.find_or_create_by!(name: name) do |ott|
    ott.description = attrs[:description]
    ott.additional_attribute_keys = attrs[:keys]
  end
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

# Source exclusions — link patterns never worth turning into a source. The
# Hacker News rules are the counterpart to the starting point seeded above:
# polling the front page is the point, and the comment thread hanging off every
# story on it is not, so without these a crawl from it spends its whole page
# budget on discussion. The Federal Register one is seeded disabled, both as an
# example of parking a rule rather than deleting it and so the seeded link
# sample below still has an external link to extract.
[
  { pattern: "https://news.ycombinator.com/item?id=*",
    description: "Comment threads. No organizations, parts or facilities worth extracting.",
    is_enabled: true },
  { pattern: "https://news.ycombinator.com/user?id=*",
    description: "Commenter profiles — a karma score and a join date.",
    is_enabled: true },
  { pattern: "https://*.wikipedia.org/wiki/Special:*",
    description: "Wikipedia's generated pages (random article, recent changes, what links here) — " \
                 "no stable content behind them.",
    is_enabled: true },
  { pattern: "https://www.federalregister.gov/documents/*",
    description: "Example of a parked rule: kept for the wording, switched off so it does not apply.",
    is_enabled: false }
].each do |attrs|
  SourceExclusion.find_or_create_by!(pattern: attrs[:pattern]) do |exclusion|
    exclusion.description = attrs[:description]
    exclusion.is_enabled  = attrs[:is_enabled]
  end
end

# Bulk imports, so the index and the show page have something to render.
# Deliberately three different shapes: one clean, one carrying the rejections
# that are the whole point of the report, and one that fell over.
#
# Keyed on raw_urls so re-running seeds does not stack up copies. No Sources are
# created here — these are the record of an import, not the import itself, and
# ImportSourcesJob is what creates rows.
[
  { raw_urls: "https://www.darpa.mil/research/programs\nhttps://www.darpa.mil/about-us/offices\n",
    status: "complete", submitted: 2, created: 2, existing: 0, rejected: [] },
  { raw_urls: "https://www.nasa.gov/directorates\nhttps://www.nasa.gov/directorates\n" \
              "nasa.gov/centers\nnot a url at all\nhttps://\n",
    status: "complete", submitted: 5, created: 2, existing: 1,
    rejected: [ { "value" => "not a url at all", "reason" => "not a usable web address" },
                { "value" => "https://",         "reason" => "not a usable web address" } ] },
  { raw_urls: "https://www.energy.gov/national-laboratories\n",
    status: "failed", submitted: 0, created: 0, existing: 0, rejected: [],
    error: "ActiveRecord::StatementInvalid: PG::ConnectionBad: server closed the connection" }
].each do |attrs|
  SourceImport.find_or_create_by!(raw_urls: attrs[:raw_urls]) do |import|
    import.status          = attrs[:status]
    import.submitted_count = attrs[:submitted]
    import.created_count   = attrs[:created]
    import.existing_count  = attrs[:existing]
    import.rejected        = attrs[:rejected]
    import.error_message   = attrs[:error]
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
      <a href="https://news.ycombinator.com/item?id=8863">Excluded by a source exclusion</a>
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

# Referenced both by the link graph below and by the knowledge base seeds, so
# it is created here — above the guard — where every environment reaches it.
apollo_source = Source.find_or_create_by!(url: "https://en.wikipedia.org/wiki/Apollo_Guidance_Computer") do |s|
  s.description = "Wikipedia: Apollo Guidance Computer."
end

# The Apollo source is linked to from the sample page but was seeded
# independently, so it keeps its own (absent) parentage — the case where an
# edge exists without the link having created the target. Created here rather
# than in db/seeds/knowledge_base.rb because a Source is not knowledge content:
# the link graph and the learning set below reference it whether or not the
# knowledge base is seeded. That file looks the same row up by URL.
apollo_source = Source.find_or_create_by!(url: "https://en.wikipedia.org/wiki/Apollo_Guidance_Computer") do |s|
  s.description = "Wikipedia: Apollo Guidance Computer."
end

SourceLink.record(from: link_sample_source, to: apollo_source)

# And a link back the other way, so at least one source shows both inbound and
# outbound edges.
SourceLink.record(from: link_sample_children.first, to: link_sample_source)

# Fetch history for the domain page, covering every outcome so the table shows
# each badge and the failure count is non-zero, and every trigger so the
# "Started by" column is not uniformly "Crawl".
fetch_log_domain = link_sample_source.domain

# A robots.txt on the domain page, so the "what it says" panel and the
# site-requested delay both render without waiting for a real crawl.
if fetch_log_domain.robots_status.blank?
  fetch_log_domain.update!(
    robots_status: "ok",
    robots_fetched_at: 2.hours.ago,
    robots_crawl_delay_seconds: 2,
    robots_txt: <<~ROBOTS
      User-agent: *
      Crawl-delay: 2
      Disallow: /search
      Disallow: /*/print$

      Sitemap: https://www.nasa.gov/sitemap.xml
    ROBOTS
  )
end

begin
  [
    { url: link_sample_source.url,                    outcome: "ok",          status_code: 200, trigger: "crawl" },
    { url: link_sample_children.first.url,            outcome: "ok",          status_code: 200, trigger: "crawl" },
    { url: "#{link_sample_source.url}by-hand",        outcome: "ok",          status_code: 200, trigger: "manual" },
    { url: "#{link_sample_source.url}just-added",     outcome: "ok",          status_code: 200, trigger: "initial" },
    { url: "#{link_sample_source.url}missing-page",   outcome: "http_error",  status_code: 404, trigger: "crawl" },
    { url: "#{link_sample_source.url}rate-limited",   outcome: "http_error",  status_code: 429, trigger: "crawl" },
    { url: "#{link_sample_source.url}brochure.pdf",   outcome: "unusable",    status_code: 200, trigger: "manual" },
    { url: "#{link_sample_source.url}slow-endpoint",  outcome: "no_response", status_code: nil, trigger: "crawl" },
    { url: "#{link_sample_source.url}already-held",   outcome: "skipped",     status_code: nil, trigger: "crawl" },
    { url: "#{link_sample_source.url}search?q=x",     outcome: "disallowed",  status_code: nil, trigger: "crawl" }
  ].each_with_index do |attrs, index|
    # Guarded per row rather than on the domain having no history at all, so a
    # database seeded before a row was added still gains it.
    record = FetchRecord.find_or_initialize_by(url: attrs[:url], domain: fetch_log_domain)
    next if record.persisted?

    record.assign_attributes(attrs.except(:url))
    record.save!
    # Spread over an afternoon so "most recent first" is visibly doing something.
    record.update_columns(created_at: index.hours.ago)
  end
end

# An example learning set, so the list, the show page and the source page's
# "add to a learning set" dropdown all have something to work with. `add_url`
# reuses the source already seeded above rather than creating a second row for
# the same page, which is the behaviour worth demonstrating.
learning_set = LearningSet.find_or_create_by!(name: "Org extraction regression") do |ls|
  ls.description = "Pages we re-run organization extraction against when a skill changes."
end

[
  link_sample_source.url,
  apollo_source.url,
  "https://en.wikipedia.org/wiki/NASA"
].each { |url| learning_set.add_url(url) }

# The starting learning set for "Pull Part Specifications": real manufacturer
# spec pages, deliberately uneven. Four dense DJI tables make the easy case, a
# non-DJI vendor makes sure the skill is not learning one page's layout, and the
# Skydio page — which leads with marketing and buries its numbers — is the one
# worth failing on. Pages are added, not fetched: fetch them from the source page
# when you want to run against them.
part_spec_learning_set = LearningSet.find_or_create_by!(name: "Product specification pages") do |ls|
  ls.description = "Manufacturer spec pages we run part-specification extraction against. " \
                   "Mixed on purpose: dense tables, a second vendor's format, and one page " \
                   "that states its numbers in prose."
end

[
  "https://www.dji.com/air-3s/specs",
  "https://www.dji.com/mavic-3-pro/specs",
  "https://www.dji.com/mini-4-pro/specs",
  "https://www.dji.com/matrice-350-rtk/specs",
  "https://www.parrot.com/en/drones/anafi-usa/technical-specifications",
  "https://www.freeflysystems.com/astro/specs",
  "https://skydio.com/x10"
].each { |url| part_spec_learning_set.add_url(url) }

# The triage configuration page reads a singleton row, created on first read.
# Seeding it means the page renders a saved record rather than creating one on
# the first visit. Left with both fields blank on purpose: a seeded prompt or a
# seeded model would look like a decision someone made, and the page's whole
# point is showing which of the two are still defaults.
TriageConfiguration.current.save!

# An example skill evaluation over that set, so the list, the configuration form
# and the result detail page all have something to show without spending money
# on a real run. Skipped entirely when no models have been refreshed yet — the
# registry is populated from the providers, not from seeds.
# Four, so the seeded comparison can show a baseline plus the three ways a model
# goes wrong against it: faithful, timid, and inventive. With fewer, the
# agreement columns render one row and demonstrate nothing.
evaluation_models = Model.selectable.first(4)
evaluation_skill  = Skill.find_by(name: "Pull Organization Names")

# A proposal in the shape ProposalRecorder normalises entries into.
def seeded_org(name, acronym = nil)
  { "type" => "organization", "name" => name, "acronym" => acronym, "attributes" => {} }.compact
end

if evaluation_models.any? && evaluation_skill&.skill_revisions&.any?
  evaluation = SkillEvaluation.find_or_create_by!(name: "Org extraction — model comparison") do |e|
    e.description  = "Does a cheaper model pull the same organizations off a page as the baseline?"
    e.skill        = evaluation_skill
    e.learning_set = learning_set
    e.base_model   = evaluation_models.first
  end

  evaluation.models = evaluation_models

  # One seeded result per model on one page, so the results table and the detail
  # page render. The response text is obviously synthetic — a seeded row must
  # never be mistaken for something a model actually said.
  revision = evaluation_skill.skill_revisions.order(:sequence).last

  evaluation_models.each_with_index do |model, index|
    result = evaluation.skill_evaluation_results
                       .find_or_initialize_by(source: link_sample_source, model: model,
                                              skill_revision: revision)

    result.assign_attributes(
      status: "complete",
      response: "[seeded placeholder — not a real model response]\n\n" \
                "Organizations found on this page:\n- NASA\n- Example Corp",
      started_at: 2.minutes.ago,
      completed_at: 1.minute.ago
    )

    # Each model fails differently, so the agreement columns have all three
    # shapes to render and the ranking has a reason to disagree with the
    # contribution column. Nothing here was proposed by a model — an evaluation
    # records these through the recording stand-ins.
    baseline_proposals = [ seeded_org("nasa", "nasa"), seeded_org("example corp") ]

    result.record_proposals(
      case index
      when 0 then baseline_proposals                      # the baseline itself
      when 1 then baseline_proposals                      # faithful: agrees completely
      when 2 then [ seeded_org("nasa", "nasa") ]          # timid: precise, but stopped early
      else                                                # inventive: finds everything, plus
        baseline_proposals + [ seeded_org("acme aerospace"), seeded_org("globex"),
                               seeded_org("initech") ]
      end
    )
    result.save!
  end

  # A second evaluation whose models came from an objective rather than from
  # ticking boxes, so the "Chosen by objective" line on the show page and the
  # pre-checked suggested set on the form both have something to render. The
  # models are derived the same way the form derives them.
  cheapest = ModelSlate.call(objective: "cheapest", models: Model.selectable.to_a,
                             baseline: evaluation_models.first, count: 3)

  if cheapest.any?
    by_objective = SkillEvaluation.find_or_create_by!(name: "Org extraction — cheapest viable") do |e|
      e.description     = "How far down the price list can this skill go before it stops finding organizations?"
      e.skill           = evaluation_skill
      e.learning_set    = learning_set
      e.base_model      = evaluation_models.first
      e.model_objective = "cheapest"
    end

    by_objective.models = cheapest.map(&:model)
  end
end

# Processing history for one page, so the reports index and the Processing
# section of the source page both have every shape they render:
#
#   - a failure that recorded why, and one that did not. The second is what every
#     report that failed before `error` existed looks like — their messages went
#     to the log only — and both pages have to stay readable for them.
#   - a report against the page's current content, and one against content the
#     page no longer has. That pair is the Content column: only the superseded
#     one could be run again.
#
# All three are seeded `failed` on purpose. A seeded "complete" report would
# claim a run happened and entities were written, and nothing here wrote any.
current_hash = link_sample_source.latest_datum&.content_hash

[
  { skill: pull_organization_names, hash: current_hash,
    error: "ProcessReportJob::ReportNotProcessable: source has no fetched data" },
  { skill: pull_part_specifications, hash: current_hash, error: nil },
  { skill: pull_organization_names, hash: "seeded-hash-of-an-earlier-fetch",
    error: "RubyLLM::Error: model: claude-3-5-haiku-20241022" }
].each do |attrs|
  revision = attrs[:skill].skill_revisions.order(:sequence).last
  next if revision.nil?

  # Keyed on the content hash too, because that is what makes the third row a
  # separate report rather than a duplicate of the first.
  report = SourceProcessingReport.find_or_initialize_by(source: link_sample_source,
                                                        skill_revision: revision,
                                                        content_hash: attrs[:hash])
  report.assign_attributes(status: "failed", facts: [], error: attrs[:error])
  report.save!
end

# ---------------------------------------------------------------------------
# Knowledge base content — tier 1 entities (Person, Organization, Part,
# Facility), their detail records, and the relationships between them.
#
# This is demo data. It is skipped outside development and test so a real
# deployment starts with an empty knowledge base, in the same spirit as the
# admin user at the top of this file. Skills, sources, and the type
# taxonomies above are seeded in every environment.
#
# Set SEED_KNOWLEDGE_BASE=true to force it on (or =false to force it off).
# ---------------------------------------------------------------------------
seed_knowledge_base = ActiveModel::Type::Boolean.new.cast(
  ENV.fetch("SEED_KNOWLEDGE_BASE", Rails.env.local?.to_s)
)

if seed_knowledge_base
  load Rails.root.join("db/seeds/knowledge_base.rb").to_s
else
  puts "Skipping knowledge base seeds (SEED_KNOWLEDGE_BASE=false). " \
       "Skills, sources, and type taxonomies were still seeded."
end
