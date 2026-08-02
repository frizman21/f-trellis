require "test_helper"
require "zip"

class SkillTriageTest < ActiveSupport::TestCase
  # Stands in for a RubyLLM chat. Counts how many were created, which is the
  # property this whole change exists for.
  Reply = Struct.new(:content)

  class FakeChat
    class << self
      attr_accessor :created, :response, :raise_with, :last_prompt, :last_schema,
                    :last_instructions, :last_model
    end

    def self.reset(response: nil, raise_with: nil)
      self.created = 0
      self.response = response
      self.raise_with = raise_with
      self.last_prompt = nil
      self.last_schema = nil
      self.last_instructions = nil
      self.last_model = nil
    end

    def initialize(model: nil)
      self.class.created += 1
      self.class.last_model = model
    end

    def with_instructions(content)
      self.class.last_instructions = content
      self
    end

    def with_schema(schema)
      self.class.last_schema = schema
      self
    end

    def ask(prompt)
      self.class.last_prompt = prompt
      raise self.class.raise_with if self.class.raise_with

      Reply.new(self.class.response)
    end
  end

  def with_fake_chat(response: nil, raise_with: nil)
    FakeChat.reset(response: response, raise_with: raise_with)
    original = Chat.method(:create!)
    Chat.define_singleton_method(:create!) { |*, **kwargs| FakeChat.new(model: kwargs[:model]) }
    yield
  ensure
    Chat.define_singleton_method(:create!, original)
  end

  setup do
    @source = Source.create!(url: "https://triage.test/exhibitors")
    @source.update!(status: "complete")
    attach("<html><body><p>Acme Corp</p><p>Beta Inc</p></body></html>")

    @orgs = make_skill("Pull orgs", "Directory and exhibitor pages.")
    @news = make_skill("Acquisition news", "Articles announcing an acquisition.")
  end

  def attach(html)
    bytes = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry("page.html")
      zos.write(html)
    end
    bytes.rewind

    SourceDatum.create!(source: @source, content_type: "application/zip", data: bytes.read)
  end

  def make_skill(name, applicability, active: true, revision: true)
    skill = Skill.create!(name: name, applicability: applicability, is_active: active)
    skill.skill_revisions.create!(content: "Do #{name}.") if revision
    skill
  end

  def verdicts_json(*pairs)
    { verdicts: pairs.map { |skill, applies, reason|
      { skill_id: skill.id, applies: applies, reason: reason }
    } }.to_json
  end

  test "returns only the skills the response says apply" do
    response = verdicts_json([ @orgs, true, "Names many companies." ],
                             [ @news, false, "No transaction described." ])

    result = with_fake_chat(response: response) { SkillTriage.call(source: @source) }

    assert_not result.failed?
    assert_equal [ @orgs ], result.recommended.map(&:skill)
    assert_equal [ @news ], result.skipped.map(&:skill)
    assert_equal "Names many companies.", result.recommended.first.reason
  end

  test "makes exactly one call regardless of how many skills are candidates" do
    3.times { |i| make_skill("Extra #{i}", "Something #{i}.") }
    assert_equal 5, Skill.triageable.count

    response = verdicts_json([ @orgs, true, "yes" ])
    with_fake_chat(response: response) { SkillTriage.call(source: @source) }

    assert_equal 1, FakeChat.created,
      "triage must cost one call, not one per skill — that is the entire point"
  end

  test "fails open when the response is malformed" do
    result = with_fake_chat(response: "not json at all") { SkillTriage.call(source: @source) }

    assert result.failed?
    assert_equal Skill.triageable.count, result.recommended.size
    assert_match(/could not decide/i, result.error)
  end

  test "fails open when the response names only unknown skill ids" do
    response = { verdicts: [ { skill_id: 999_999, applies: true, reason: "?" } ] }.to_json

    result = with_fake_chat(response: response) { SkillTriage.call(source: @source) }

    assert result.failed?
    assert_equal Skill.triageable.count, result.recommended.size
  end

  test "fails open when the chat raises" do
    result = with_fake_chat(raise_with: RuntimeError.new("provider down")) do
      SkillTriage.call(source: @source)
    end

    assert result.failed?
    assert_equal Skill.triageable.count, result.recommended.size
    assert_match(/provider down/, result.error)
  end

  test "ignores verdicts for skills that were not candidates" do
    other = make_skill("Not a candidate", "Elsewhere.")
    response = verdicts_json([ @orgs, true, "yes" ], [ other, true, "sneaked in" ])

    result = with_fake_chat(response: response) do
      SkillTriage.call(source: @source, skills: [ @orgs, @news ])
    end

    assert_equal [ @orgs ], result.recommended.map(&:skill)
    assert_not_includes result.verdicts.map(&:skill), other
  end

  test "excludes inactive skills and skills without a revision or statement" do
    make_skill("Inactive", "Somewhere.", active: false)
    make_skill("No revision", "Somewhere.", revision: false)

    assert_equal [ @orgs, @news ].map(&:id).sort, Skill.triageable.pluck(:id).sort
  end

  test "makes no call and recommends nothing when there are no candidate skills" do
    result = with_fake_chat(response: verdicts_json) do
      SkillTriage.call(source: @source, skills: [])
    end

    assert_equal 0, FakeChat.created
    assert_empty result.recommended
    assert_not result.failed?
  end

  test "fails open without calling when the source has no extractable text" do
    empty = Source.create!(url: "https://triage.test/empty")

    result = with_fake_chat(response: verdicts_json) { SkillTriage.call(source: empty) }

    assert_equal 0, FakeChat.created, "no point paying to triage a page with no text"
    assert result.failed?
    assert_equal Skill.triageable.count, result.recommended.size
  end

  test "truncates the excerpt so triage does not resend the whole page" do
    long = "Exhibitor name. " * 2_000
    attach("<html><body><p>#{long}</p></body></html>")
    assert @source.source_data.order(:created_at).last.text.length > 20_000

    with_fake_chat(response: verdicts_json([ @orgs, true, "yes" ])) do
      SkillTriage.call(source: @source)
    end

    prompt = FakeChat.last_prompt
    assert prompt.length < SkillTriage::EXCERPT_LIMIT + 2_000,
      "expected a bounded excerpt, got a #{prompt.length}-char prompt"
  end

  test "the prompt names each skill's applicability and the page url" do
    with_fake_chat(response: verdicts_json([ @orgs, true, "yes" ])) do
      SkillTriage.call(source: @source, skills: [ @orgs ])
    end

    prompt = FakeChat.last_prompt
    assert_includes prompt, "Directory and exhibitor pages."
    assert_includes prompt, "id #{@orgs.id}"
    assert_includes prompt, @source.url
  end

  # --- url patterns -------------------------------------------------------

  test "a skill whose pattern matches the url is picked without any call" do
    linkedin = make_skill("LinkedIn-Person", "LinkedIn profiles.")
    linkedin.update!(url_patterns: [ 'triage\.test/exhibitors' ])

    result = with_fake_chat(response: verdicts_json) { SkillTriage.call(source: @source) }

    assert_equal 0, FakeChat.created, "the URL settles it; paying to ask is waste"
    assert_not result.failed?
    assert result.routed_by_url
    assert_equal [ linkedin ], result.recommended.map(&:skill)
  end

  test "a url claim excludes every other candidate skill" do
    linkedin = make_skill("LinkedIn-Person", "LinkedIn profiles.")
    linkedin.update!(url_patterns: [ 'triage\.test/exhibitors' ])

    result = with_fake_chat(response: verdicts_json) { SkillTriage.call(source: @source) }

    assert_equal [ @news, @orgs ].map(&:name).sort, result.skipped.map { |v| v.skill.name }.sort
    assert_match(/LinkedIn-Person/, result.skipped.first.reason)
  end

  test "the claiming verdict names the pattern that matched" do
    linkedin = make_skill("LinkedIn-Person", "LinkedIn profiles.")
    linkedin.update!(url_patterns: [ 'triage\.test/exhibitors' ])

    result = with_fake_chat(response: verdicts_json) { SkillTriage.call(source: @source) }

    assert_match %r{triage\\\.test/exhibitors}, result.recommended.first.reason
  end

  test "two skills claiming the same url both run" do
    a = make_skill("Claim A", "Somewhere.")
    b = make_skill("Claim B", "Somewhere.")
    a.update!(url_patterns: [ 'triage\.test' ])
    b.update!(url_patterns: [ "/exhibitors" ])

    result = with_fake_chat(response: verdicts_json) { SkillTriage.call(source: @source) }

    assert_equal 0, FakeChat.created
    assert_equal [ a, b ], result.recommended.map(&:skill)
  end

  test "a pattern matching no url leaves triage to the model" do
    make_skill("LinkedIn-Person", "LinkedIn profiles.").update!(url_patterns: [ 'linkedin\.com/in/' ])

    result = with_fake_chat(response: verdicts_json([ @orgs, true, "yes" ])) do
      SkillTriage.call(source: @source)
    end

    assert_equal 1, FakeChat.created
    assert_not result.routed_by_url
    assert_equal [ @orgs ], result.recommended.map(&:skill)
  end

  test "a claim only counts among the candidate skills given" do
    outsider = make_skill("Outsider", "Somewhere.")
    outsider.update!(url_patterns: [ 'triage\.test' ])

    result = with_fake_chat(response: verdicts_json([ @orgs, true, "yes" ])) do
      SkillTriage.call(source: @source, skills: [ @orgs, @news ])
    end

    assert_equal 1, FakeChat.created, "a skill that was not a candidate cannot claim the page"
    assert_not_includes result.verdicts.map(&:skill), outsider
  end

  test "a claimed page is routed even when it has no extractable text" do
    empty = Source.create!(url: "https://triage.test/empty")
    linkedin = make_skill("LinkedIn-Person", "LinkedIn profiles.")
    linkedin.update!(url_patterns: [ 'triage\.test/empty' ])

    result = with_fake_chat(response: verdicts_json) { SkillTriage.call(source: empty) }

    assert_equal 0, FakeChat.created
    assert_not result.failed?, "the URL is enough; there is nothing to fail open about"
    assert_equal [ linkedin ], result.recommended.map(&:skill)
  end

  test "asks for a structured response rather than scraping prose" do
    with_fake_chat(response: verdicts_json([ @orgs, true, "yes" ])) do
      SkillTriage.call(source: @source)
    end

    assert_not_nil FakeChat.last_schema, "expected triage to constrain the response shape"
  end

  # --- configuration ------------------------------------------------------

  # One shared timestamp: Model.current keeps only the rows from the most
  # recent refresh, so models stamped microseconds apart would leave the
  # earlier ones out of `selectable` entirely.
  def make_model(provider, model_id)
    @refreshed_at ||= Time.current
    Model.create!(provider: provider, model_id: model_id, name: model_id, last_seen_at: @refreshed_at)
  end

  test "sends the configured instructions and model" do
    pinned = make_model("openai", "gpt-zzz")
    make_model("anthropic", "claude-aaa")
    TriageConfiguration.create!(instructions: "Route only parts pages.", model: pinned)

    with_fake_chat(response: verdicts_json([ @orgs, true, "yes" ])) do
      SkillTriage.call(source: @source)
    end

    assert_equal "Route only parts pages.", FakeChat.last_instructions
    assert_equal pinned, FakeChat.last_model
  end

  test "falls back to the default instructions and the first selectable model" do
    fallback = make_model("anthropic", "claude-aaa")
    make_model("openai", "gpt-zzz")

    with_fake_chat(response: verdicts_json([ @orgs, true, "yes" ])) do
      SkillTriage.call(source: @source)
    end

    assert_equal TriageConfiguration::DEFAULT_INSTRUCTIONS, FakeChat.last_instructions
    assert_equal fallback, FakeChat.last_model
  end

  test "an explicit model overrides the configured one" do
    pinned = make_model("openai", "gpt-zzz")
    asked_for = make_model("anthropic", "claude-aaa")
    TriageConfiguration.create!(model: pinned)

    with_fake_chat(response: verdicts_json([ @orgs, true, "yes" ])) do
      SkillTriage.call(source: @source, model: asked_for)
    end

    assert_equal asked_for, FakeChat.last_model,
      "an evaluation asking for a model is not asking what triage is configured to use"
  end

  # --- preview ------------------------------------------------------------

  test "preview makes no call and stores nothing" do
    make_model("anthropic", "claude-aaa")

    preview = nil
    assert_no_difference [ "Chat.count", "TriageConfiguration.count" ] do
      with_fake_chat(response: verdicts_json) { preview = SkillTriage.preview(source: @source) }
    end

    assert_equal 0, FakeChat.created
    assert_not_nil preview.prompt
  end

  test "preview renders the prompt a real call would send" do
    make_model("anthropic", "claude-aaa")

    preview = SkillTriage.preview(source: @source, skills: [ @orgs ])

    with_fake_chat(response: verdicts_json([ @orgs, true, "yes" ])) do
      SkillTriage.call(source: @source, skills: [ @orgs ])
    end

    assert_equal FakeChat.last_prompt, preview.prompt
    assert_equal FakeChat.last_instructions, preview.instructions
    assert_equal FakeChat.last_model, preview.model
  end

  test "preview stands in for the excerpt when the page has no text" do
    empty = Source.create!(url: "https://triage.test/empty")

    preview = SkillTriage.preview(source: empty)

    assert_not preview.excerpt?
    assert_includes preview.prompt, SkillTriage::PREVIEW_PLACEHOLDER_EXCERPT
  end

  test "preview names the skills that would claim the url without a call" do
    linkedin = make_skill("LinkedIn-Person", "LinkedIn profiles.")
    linkedin.update!(url_patterns: [ 'triage\.test' ])

    preview = SkillTriage.preview(source: @source)

    assert preview.routed_by_url?
    assert_equal [ linkedin ], preview.claimants
  end

  test "preview reports no claimants for a page triage would actually ask about" do
    preview = SkillTriage.preview(source: @source)

    assert_not preview.routed_by_url?
  end

  test "preview renders without a source at all" do
    preview = SkillTriage.preview

    assert_equal 0, Chat.count
    assert_includes preview.prompt, "id #{@orgs.id}"
    assert_not preview.excerpt?
  end
end
