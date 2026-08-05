require "test_helper"
require "zip"

class SourcesControllerTest < ActionDispatch::IntegrationTest
  # A page with content attached, so its reports have a content hash to agree or
  # disagree with.
  def source_with_content(url, html)
    source = Source.create!(url: url)
    source.update!(status: "complete")

    bytes = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry("page.html")
      zos.write(html)
    end
    bytes.rewind
    SourceDatum.create!(source: source, content_type: "application/zip", data: bytes.read)

    source
  end

  def report_on(source, skill_name:, **attrs)
    skill = Skill.create!(name: skill_name)
    revision = skill.skill_revisions.create!(content: "Do the thing.")

    SourceProcessingReport.create!({ source: source, skill_revision: revision,
                                     status: "complete", facts: [] }.merge(attrs))
  end
  test "index renders and paginates without raising NoMethodError" do
    get sources_path
    assert_response :success
  end

  test "relation responds to #page (Kaminari wired in)" do
    assert Source.all.respond_to?(:page),
      "expected ActiveRecord::Relation to respond to #page — is kaminari loaded?"
  end

  test "show page renders the crawl form" do
    get source_path(sources(:one))
    assert_response :success
    assert_select "form[action=?]", crawl_source_path(sources(:one))
    assert_select "select[name=?]", "crawl_type"
    assert_select "input[name=?]", "max_depth"
    assert_select "input[name=?]", "max_pages"
  end

  test "show page names the parent source and links to both link pages with counts" do
    parent = sources(:two)
    source = Source.create!(url: "https://example.com/middle", parent_source: parent)
    downstream = Source.create!(url: "https://example.com/downstream")

    SourceLink.record(from: source, to: downstream)
    SourceLink.record(from: parent, to: source)

    get source_path(source)

    assert_response :success
    assert_select "dt", text: "Parent source"
    assert_select "a[href=?]", source_path(parent)
    assert_select "a[href=?]", links_from_source_path(source), text: /Links from this source \(1\)/
    assert_select "a[href=?]", links_to_source_path(source), text: /Links to this source \(1\)/
  end

  test "show page renders for a source with no parent and no links" do
    source = sources(:one)

    get source_path(source)

    assert_response :success
    assert_select "a[href=?]", links_from_source_path(source), text: /Links from this source \(0\)/
    assert_select "a[href=?]", links_to_source_path(source), text: /Links to this source \(0\)/
  end

  test "links_from page lists the sources this one links out to" do
    source = sources(:one)
    downstream = Source.create!(url: "https://example.com/downstream")
    SourceLink.record(from: source, to: downstream)

    get links_from_source_path(source)

    assert_response :success
    assert_select "a[href=?]", source_path(downstream)
    assert_select "a[href=?]", source_path(source), text: "Back to source"
  end

  test "links_to page lists the sources linking here" do
    source = sources(:one)
    upstream = Source.create!(url: "https://example.com/upstream")
    SourceLink.record(from: upstream, to: source)

    get links_to_source_path(source)

    assert_response :success
    assert_select "a[href=?]", source_path(upstream)
  end

  test "link pages are directional" do
    source = sources(:one)
    downstream = Source.create!(url: "https://example.com/downstream")
    SourceLink.record(from: source, to: downstream)

    get links_to_source_path(source)

    assert_response :success
    assert_select "a[href=?]", source_path(downstream), count: 0
    assert_match(/No other source is known to link here/, response.body)
  end

  test "link pages render and paginate when empty" do
    source = sources(:one)

    get links_from_source_path(source)
    assert_response :success
    assert_match(/No outbound links recorded/, response.body)

    get links_to_source_path(source)
    assert_response :success
    assert_match(/No other source is known to link here/, response.body)
  end

  test "links_from paginates" do
    source = sources(:one)
    60.times { |i| SourceLink.record(from: source, to: Source.create!(url: "https://example.com/p#{i}")) }

    get links_from_source_path(source)

    assert_response :success
    assert_select "tbody tr", 50
    assert_match(/Showing 50 of 60/, response.body)
  end

  test "show page always offers a fetch button" do
    new_source = sources(:one)
    done_source = Source.create!(url: "https://example.com/done")
    done_source.update!(status: "complete")

    get source_path(new_source)
    assert_select "form[action=?]", fetch_source_path(new_source)
    assert_select "button", text: "Fetch content"

    get source_path(done_source)
    assert_select "form[action=?]", fetch_source_path(done_source)
    assert_select "button", text: "Re-fetch content"
  end

  test "fetch enqueues a forced FetchSourceJob for a source in status new" do
    source = sources(:one)

    assert_enqueued_with(job: FetchSourceJob, args: [ source, { force: true } ]) do
      post fetch_source_path(source)
    end

    assert_redirected_to source_path(source)
    follow_redirect!
    assert_match(/Fetch queued/, response.body)
  end

  test "fetch enqueues for a source that is already complete" do
    source = Source.create!(url: "https://example.com/already-done")
    source.update!(status: "complete")

    assert_enqueued_with(job: FetchSourceJob, args: [ source, { force: true } ]) do
      post fetch_source_path(source)
    end

    follow_redirect!
    assert_match(/Re-fetch queued/, response.body)
    assert_match(/was complete/, response.body)
  end

  test "fetch enqueues for a source that previously failed" do
    source = Source.create!(url: "https://example.com/broken")
    source.update!(status: "failed")

    assert_enqueued_jobs 1, only: FetchSourceJob do
      post fetch_source_path(source)
    end
  end

  # --- create -------------------------------------------------------------

  # Unforced, unlike the manual button above: the job returns unless the status
  # is still `new`, which is what keeps this from clobbering a crawl's content.
  test "create enqueues an unforced fetch for the new source" do
    assert_enqueued_jobs 1, only: FetchSourceJob do
      post sources_path, params: { source: { url: "https://example.com/fresh" } }
    end

    source = Source.find_by(url: "https://example.com/fresh")
    assert_not_nil source
    assert_enqueued_with(job: FetchSourceJob, args: [ source ])
    assert_redirected_to source_path(source)
    follow_redirect!
    assert_match(/fetch queued/i, response.body)
  end

  test "create with an unusable url re-renders and enqueues nothing" do
    assert_no_enqueued_jobs only: FetchSourceJob do
      post sources_path, params: { source: { url: "" } }
    end

    assert_response :unprocessable_entity
  end

  # --- triage -------------------------------------------------------------

  def triage_source
    source = Source.create!(url: "https://triage.test/page")
    source.update!(status: "complete")
    bytes = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry("page.html")
      zos.write("<html><body><p>Acme Corp</p></body></html>")
    end
    bytes.rewind
    SourceDatum.create!(source: source, content_type: "application/zip", data: bytes.read)
    source
  end

  def make_skill(name, applicability)
    skill = Skill.create!(name: name, applicability: applicability, is_active: true)
    skill.skill_revisions.create!(content: "Do #{name}.")
    skill
  end

  def stub_triage(recommended:, skipped: [], routed_by_url: false)
    verdicts = recommended.map { |s| SkillTriage::Verdict.new(skill: s, applies: true, reason: "yes") } +
               skipped.map { |s| SkillTriage::Verdict.new(skill: s, applies: false, reason: "no") }
    result = SkillTriage::Result.new(verdicts: verdicts, failed: false, routed_by_url: routed_by_url)

    original = SkillTriage.method(:call)
    SkillTriage.define_singleton_method(:call) { |**| result }
    yield
  ensure
    SkillTriage.define_singleton_method(:call, original)
  end

  test "show offers the triage button only when the source has data" do
    empty = Source.create!(url: "https://triage.test/empty")

    get source_path(empty)
    assert_select "a[href=?]", triage_source_path(empty), count: 0

    with_data = triage_source
    get source_path(with_data)
    assert_select "a[href=?]", triage_source_path(with_data), text: "Suggest skills"
  end

  test "triage pre-checks recommended skills and leaves the rest unchecked" do
    source = triage_source
    yes = make_skill("Recommended", "Directory pages.")
    no  = make_skill("Not recommended", "Acquisition articles.")

    stub_triage(recommended: [ yes ], skipped: [ no ]) { get triage_source_path(source) }

    assert_response :success
    assert_select "input[name='skill_ids[]'][value=?][checked]", yes.id.to_s
    assert_select "input[name='skill_ids[]'][value=?]:not([checked])", no.id.to_s
  end

  test "triage says so when a url pattern picked the skill instead of a call" do
    source = triage_source
    claimed = make_skill("LinkedIn-Person", "LinkedIn profiles.")
    other   = make_skill("Summarize", "Prose pages.")

    stub_triage(recommended: [ claimed ], skipped: [ other ], routed_by_url: true) do
      get triage_source_path(source)
    end

    assert_response :success
    assert_match(/Routed by URL pattern/, response.body)
    assert_no_match(/One triage call judged/, response.body)
    assert_select "input[name='skill_ids[]'][value=?][checked]", claimed.id.to_s
  end

  test "triage creates one report and one job per selected skill" do
    source = triage_source
    a = make_skill("Skill A", "Directory pages.")
    b = make_skill("Skill B", "Other pages.")

    assert_difference "SourceProcessingReport.count", 2 do
      assert_enqueued_jobs 2, only: ProcessReportJob do
        post triage_source_path(source), params: { skill_ids: [ a.id, b.id ] }
      end
    end

    assert_equal [ a.id, b.id ].sort,
                 SourceProcessingReport.last(2).map { |r| r.skill_revision.skill_id }.sort
  end

  test "triage queues nothing when no skills are selected" do
    source = triage_source
    make_skill("Skill A", "Directory pages.")

    assert_no_difference "SourceProcessingReport.count" do
      assert_no_enqueued_jobs only: ProcessReportJob do
        post triage_source_path(source), params: { skill_ids: [] }
      end
    end

    assert_redirected_to source_path(source)
    follow_redirect!
    assert_match(/No skills selected/, response.body)
  end

  test "triage does not duplicate a report already covering this content" do
    source = triage_source
    skill = make_skill("Skill A", "Directory pages.")

    post triage_source_path(source), params: { skill_ids: [ skill.id ] }

    assert_no_difference "SourceProcessingReport.count" do
      assert_no_enqueued_jobs only: ProcessReportJob do
        post triage_source_path(source), params: { skill_ids: [ skill.id ] }
      end
    end

    follow_redirect!
    assert_match(/already covered/, response.body)
  end

  test "a queued report runs the model its revision pins" do
    source = triage_source
    skill = make_skill("Skill A", "Directory pages.")
    revision_model = Model.create!(provider: "openai", model_id: "gpt-revision",
                                   name: "gpt-revision", last_seen_at: Time.current)
    skill_model = Model.create!(provider: "openai", model_id: "gpt-skill",
                                name: "gpt-skill", last_seen_at: Time.current)
    skill.update!(preferred_model: skill_model)
    skill.current_revision.update!(model: revision_model)

    post triage_source_path(source), params: { skill_ids: [ skill.id ] }

    assert_equal revision_model, SourceProcessingReport.order(:id).last.model
  end

  test "a revision with no model recorded falls back to the skill's preferred model" do
    source = triage_source
    skill = make_skill("Skill B", "Directory pages.")
    skill_model = Model.create!(provider: "openai", model_id: "gpt-fallback",
                                name: "gpt-fallback", last_seen_at: Time.current)
    skill.update!(preferred_model: skill_model)
    assert_nil skill.current_revision.model

    post triage_source_path(source), params: { skill_ids: [ skill.id ] }

    assert_equal skill_model, SourceProcessingReport.order(:id).last.model
  end

  test "triage refuses skills that are not triageable" do
    source = triage_source
    inactive = Skill.create!(name: "Inactive", applicability: "Anywhere.", is_active: false)
    inactive.skill_revisions.create!(content: "Do it.")

    assert_no_difference "SourceProcessingReport.count" do
      post triage_source_path(source), params: { skill_ids: [ inactive.id ] }
    end
  end

  test "triage warns rather than dropping work when the call fails" do
    source = triage_source
    skill = make_skill("Skill A", "Directory pages.")

    result = SkillTriage::Result.new(
      verdicts: [ SkillTriage::Verdict.new(skill: skill, applies: true, reason: "fallback") ],
      failed: true, error: "Triage could not decide (boom); recommending every candidate skill."
    )
    original = SkillTriage.method(:call)
    SkillTriage.define_singleton_method(:call) { |**| result }

    get triage_source_path(source)

    assert_response :success
    assert_match(/could not decide/, response.body)
    assert_select "input[name='skill_ids[]'][value=?][checked]", skill.id.to_s
  ensure
    SkillTriage.define_singleton_method(:call, original)
  end

  test "crawl enqueues a CrawlJob with parsed params" do
    source = sources(:one)
    assert_enqueued_with(job: CrawlJob) do
      post crawl_source_path(source),
           params: { crawl_type: "stay_in_domain", max_depth: "2", max_pages: "100" }
    end
    assert_redirected_to source_path(source)
  end

  test "show page lists the processing already done on this page" do
    source = source_with_content("https://history.test/page", "<html><body><p>Acme Corp</p></body></html>")
    model = Model.create!(provider: "anthropic", model_id: "claude-test", name: "Claude test")
    report = report_on(source, skill_name: "Pull orgs", model: model)

    get source_path(source)

    assert_response :success
    assert_match(/##{report.id}/, response.body)
    assert_match(/Pull orgs/, response.body)
    assert_match(/claude-test/, response.body)
  end

  test "show page lists only this source's reports" do
    source = source_with_content("https://history.test/mine", "<html><body><p>Mine</p></body></html>")
    other  = source_with_content("https://history.test/theirs", "<html><body><p>Theirs</p></body></html>")
    report_on(other, skill_name: "Someone else's skill")

    get source_path(source)

    assert_response :success
    assert_no_match(/Someone else's skill/, response.body)
    assert_match(/No skills have been run against this page yet/, response.body)
  end

  # The dedup rule refuses a re-run while a report still covers the current
  # content, so which of the two a row is decides whether it can be run again.
  test "show page marks a report against the current content as current" do
    source = source_with_content("https://history.test/current", "<html><body><p>Acme Corp</p></body></html>")
    report_on(source, skill_name: "Pull orgs")

    get source_path(source)

    assert_response :success
    assert_select "td span.text-success", text: /Current/
    assert_no_match(/Superseded/, response.body)
  end

  test "show page marks a report against older content as superseded" do
    source = source_with_content("https://history.test/stale", "<html><body><p>Acme Corp</p></body></html>")
    report_on(source, skill_name: "Pull orgs", content_hash: "a-hash-from-an-earlier-fetch")

    get source_path(source)

    assert_response :success
    assert_select "td span.text-muted", text: /Superseded/
  end

  test "show page shows why a report failed" do
    source = source_with_content("https://history.test/failed", "<html><body><p>Acme Corp</p></body></html>")
    report_on(source, skill_name: "Pull orgs", status: "failed",
                      error: "RubyLLM::Error: model: claude-3-5-haiku-20241022")

    get source_path(source)

    assert_response :success
    assert_match(/RubyLLM::Error: model: claude-3-5-haiku-20241022/, response.body)
  end

  test "crawl rejects unknown crawl_type without enqueueing" do
    source = sources(:one)
    assert_no_enqueued_jobs only: CrawlJob do
      post crawl_source_path(source), params: { crawl_type: "bogus", max_depth: "1" }
    end
    assert_redirected_to source_path(source)
    follow_redirect!
    assert_match(/Invalid crawl type/, response.body)
  end
end
