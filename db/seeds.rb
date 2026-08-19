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

# Projects — the named bodies of work the application organises around, and the
# list you land on at the root. Seeded in every environment: unlike the demo
# knowledge base below, an empty projects list is a dead landing page.
#
# Attempts vary across the three so the field on the project form is visible as
# something that differs per project rather than as a constant. Set on create
# only: a number somebody changed in the browser is not a seeding mistake.
{
  "Apollo Program" => 1,
  "Gemini Program" => 3,
  "Skylab" => 1
}.each do |name, attempts|
  Project.create_with(extraction_attempts: attempts).find_or_create_by!(name: name)
end

# The seeded ontology and data belong to the first project. A project's two
# sides are its own: seeding one project gives both sides something to show
# while leaving the others genuinely empty, which is the more useful demo.
seed_project = Project.order(:id).first

# The ontology — a couple of types with typed attributes, some entities of each,
# and edges between them, so the entity and entity-type screens have something to
# show on a fresh database. Idempotent: keyed on the type name and, for entities,
# on the value of their `name` attribute.
ontology = {
  "Rocket Engine" => {
    description: "A propulsion device that produces thrust by burning propellant. " \
                 "Record a specific named engine, including a variant when the source " \
                 "names it separately. Do not record a whole vehicle, which is a " \
                 "Launch Vehicle.",
    attributes: { "thrust_kn" => "float", "first_flight" => "datetime",
                  "chambers" => "int" },
    entities: [
      { "name" => "Rocketdyne F-1", "thrust_kn" => 6770.0, "first_flight" => "1967-11-09", "chambers" => 1 },
      { "name" => "Raptor 2",       "thrust_kn" => 2300.0, "first_flight" => "2023-04-20", "chambers" => 1 }
    ]
  },
  "Launch Vehicle" => {
    description: "A complete rocket that carries a payload to orbit, named as a " \
                 "vehicle rather than as one of its stages or engines. Record the " \
                 "vehicle the source names; record its engines separately as Rocket " \
                 "Engines.",
    attributes: { "stages" => "int", "payload_kg_leo" => "float" },
    entities: [
      { "name" => "Saturn V", "stages" => 3, "payload_kg_leo" => 140000.0 },
      { "name" => "Starship", "stages" => 2, "payload_kg_leo" => 100000.0 }
    ]
  }
}

seeded_entities = {}

ontology.each do |type_name, spec|
  type = seed_project.entity_types.find_or_create_by!(name: type_name) do |t|
    t.description = spec[:description]
  end

  spec[:attributes].each do |attr_name, value_type|
    type.entity_type_attributes.find_or_create_by!(name: attr_name) { |a| a.value_type = value_type }
  end

  spec[:entities].each do |values|
    # Keyed on the name column — every entity has one.
    entity = seed_project.entities.find_or_create_by!(name: values.fetch("name")) do |e|
      e.entity_type = type
    end

    values.except("name").each do |attr_name, raw|
      attribute = type.entity_type_attributes.find_by!(name: attr_name)
      record = EntityAttributeValue.find_or_initialize_by(entity: entity,
                                                          entity_type_attribute: attribute)
      record.value = raw
      record.save!
    end

    seeded_entities[values["name"]] = entity
  end
end

# Edges say what kind they are, and carry facts of their own.
# A relationship type says what it connects, and in which direction.
powers = seed_project.relationship_types.find_or_create_by!(name: "Powers") do |t|
  t.description = "The engine provides thrust for the vehicle. Record it when the " \
                  "source says which engine a vehicle uses, and record the count " \
                  "when the source gives one."
  t.from_entity_type = seed_project.entity_types.find_by!(name: "Rocket Engine")
  t.to_entity_type   = seed_project.entity_types.find_by!(name: "Launch Vehicle")
end
[
  { name: "engine_count", value_type: "int" },
  { name: "stage",        value_type: "string" }
].each do |attrs|
  powers.relationship_type_attributes.find_or_create_by!(name: attrs[:name]) do |a|
    a.value_type = attrs[:value_type]
  end
end

[
  [ "Rocketdyne F-1", "Saturn V", { "engine_count" => 5, "stage" => "First" } ],
  [ "Raptor 2",       "Starship", { "engine_count" => 33, "stage" => "Booster" } ]
].each do |from_name, to_name, values|
  from = seeded_entities[from_name]
  to   = seeded_entities[to_name]
  next if from.nil? || to.nil?

  relationship = Relationship.find_or_create_by!(from_entity: from, to_entity: to) do |r|
    r.relationship_type = powers
  end

  values.each do |attr_name, raw|
    attribute = powers.relationship_type_attributes.find_by!(name: attr_name)
    record = RelationshipTypeValue.find_or_initialize_by(relationship: relationship,
                                                         relationship_type_attribute: attribute)
    record.value = raw
    record.save!
  end
end

# The F-DoD landscape: the tier 1 model removed in #4, rebuilt as ontology.
# Its own file — several hundred lines of data would swamp this one.
load Rails.root.join("db/seeds/f_dod.rb").to_s

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

# The project side of a source, so the project's source page — where a crawl is
# started, content fetched and a model chosen for extraction — has something to
# render on a fresh database. The join is what makes a page a project's concern;
# the pages themselves are seeded above and belong to no project until this runs.
[ link_sample_source, apollo_source ].each do |source|
  ProjectSource.find_or_create_by!(project: seed_project, source: source)
end

# The extract control preselects this. Seeded only when the registry has been
# refreshed — models are populated from the providers, not from here — and only
# when the project has no default already, so a choice made in the app is not
# overwritten by re-running seeds.
if seed_project.default_model.nil? && (seed_default_model = Model.selectable.first)
  seed_project.update!(default_model: seed_default_model)
end

# A worked example of a model served from somewhere the provider refreshes never
# look, so the Model Endpoints screens render on a fresh database.
#
# Its model is seeded disabled on purpose, and that is also why the default above
# cannot pick it: a custom model is offered wherever a model is picked, and an
# endpoint that does not exist has no business being a project's default. The row
# is here to show the screens, not to be run.
example_endpoint = ModelEndpoint.find_or_create_by!(name: "Example internal endpoint") do |endpoint|
  endpoint.base_url = "https://models.example.internal/v1"
  endpoint.api_key_env_var = "EXAMPLE_ENDPOINT_PAT"
end

unless example_endpoint.models.exists?(model_id: "example-large")
  example_endpoint.models.create!(provider: "custom_endpoint", model_id: "example-large",
                                  name: "Example Large", is_disabled: true)
end
