# Development login. Idempotent — re-running seeds will not duplicate the user
# or reset an existing password. Never seeded in production.
if Rails.env.local?
  User.find_or_create_by!(email: "admin@example.com") do |user|
    user.password = "Password1"
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

# An example skill evaluation over that set, so the list, the configuration form
# and the result detail page all have something to show without spending money
# on a real run. Skipped entirely when no models have been refreshed yet — the
# registry is populated from the providers, not from seeds.
evaluation_models = Model.selectable.first(2)
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

    # The baseline and the second model propose overlapping-but-different sets,
    # so the matrix has a cell to compare, the ranking has an order and the
    # result page has a three-way split to render. Nothing here was proposed by
    # a model — an evaluation records these through the recording stand-ins.
    result.record_proposals(
      if index.zero?
        [ seeded_org("nasa", "nasa"), seeded_org("example corp") ]
      else
        [ seeded_org("nasa", "nasa"), seeded_org("acme aerospace") ]
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
