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

# Two failed reports, so the reports index has both shapes of failure to render:
# one that recorded why it failed, and one that did not. The second is what every
# report that failed before `error` existed looks like — their messages went to
# the log only — and the index has to stay readable for them.
#
# Seeded failed rather than complete on purpose: a seeded "complete" report would
# claim a run happened and entities were written, and nothing here wrote any.
[
  { skill: pull_organization_names,
    error: "ProcessReportJob::ReportNotProcessable: source has no fetched data" },
  { skill: pull_part_specifications, error: nil }
].each do |attrs|
  revision = attrs[:skill].skill_revisions.order(:sequence).last
  next if revision.nil?

  report = SourceProcessingReport.find_or_initialize_by(source: link_sample_source,
                                                        skill_revision: revision)
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
