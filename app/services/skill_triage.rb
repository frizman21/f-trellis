require "ruby_llm/schema"

# Decides which skills are worth running on a page, in ONE model call.
#
# Brute force costs `skills x pages` calls. Measured on gpt-4o-mini, one page
# against one skill billed $0.0354; at 10 skills x 50,000 pages that is ~$17,700
# per pass on the cheapest model available. Most of those calls find nothing,
# because most skills do not apply to most pages.
#
# This reads each skill's applicability statement plus a bounded excerpt of the
# page and returns only the skills worth calling — one call regardless of how
# many skills exist.
#
# The instructions it judges against and the model it spends come from
# TriageConfiguration, which is editable at /triage_configuration. That page
# also renders `#preview` — the same prompt this builds, without sending it.
class SkillTriage
  # Enough of a page to tell what kind of page it is. Triage is a routing
  # decision, not an extraction, so it does not need the whole document — and
  # sending the whole document would defeat the point.
  EXCERPT_LIMIT = 4_000

  # Stands in for the page text on the configuration page when no source has
  # been fetched yet. Never sent to a model — a preview makes no call.
  PREVIEW_PLACEHOLDER_EXCERPT =
    "[no fetched page text yet — a real call puts the first " \
    "#{EXCERPT_LIMIT} characters of the page here]".freeze

  Verdict = Struct.new(:skill, :applies, :reason, keyword_init: true)

  # Everything a real call would send, without sending it. Built from the same
  # methods `#ask` uses, so the configuration page cannot show a prompt that
  # differs from the one that runs.
  Preview = Struct.new(:instructions, :prompt, :model, :source, :skills, :excerpt, :claimants,
                       keyword_init: true) do
    def excerpt? = excerpt.present?
    def routed_by_url? = claimants.present?
  end

  Result = Struct.new(:verdicts, :failed, :error, :routed_by_url, keyword_init: true) do
    def recommended = verdicts.select(&:applies)
    def skipped     = verdicts.reject(&:applies)
    def failed?     = failed
  end

  def self.call(source:, skills: nil, model: nil)
    new(source: source, skills: skills, model: model).call
  end

  # Read-only: no Chat, no provider call, nothing written.
  def self.preview(source: nil, skills: nil, model: nil)
    new(source: source, skills: skills, model: model).preview
  end

  def initialize(source: nil, skills: nil, model: nil)
    @source = source
    @skills = (skills || Skill.triageable).to_a
    @model  = model
  end

  def call
    return Result.new(verdicts: [], failed: false) if @skills.empty?

    claimed = url_claim_verdicts
    return Result.new(verdicts: claimed, failed: false, routed_by_url: true) if claimed

    excerpt = page_excerpt
    return fail_open("the source has no extractable text") if excerpt.blank?

    parse(ask(excerpt))
  rescue StandardError => e
    Rails.logger.error("SkillTriage failed for source ##{@source&.id}: #{e.class}: #{e.message}")
    # A model the provider has retired would fail every source from here on, and
    # triage runs unattended. Retiring it here is what makes the fallback in
    # TriageConfiguration#model pick a working one on the next source.
    triage_model&.deprecate_for!(e)
    fail_open("#{e.class}: #{e.message}")
  end

  # The instructions and prompt a real call would send for this source, and the
  # model it would be sent to. Nothing is asked and nothing is stored.
  def preview
    excerpt = page_excerpt

    Preview.new(
      instructions: instructions,
      prompt: prompt_for(excerpt.presence || PREVIEW_PLACEHOLDER_EXCERPT),
      model: triage_model,
      source: @source,
      skills: @skills,
      excerpt: excerpt.presence,
      claimants: url_claimants
    )
  end

  private

  # A skill can claim a URL outright with a regex. A claim states a fact about
  # the page — a LinkedIn profile is a LinkedIn profile — where applicability
  # only invites a guess, so a match wins and costs nothing: the whole triage
  # call is skipped. Everything else is left unchecked rather than removed, so
  # an operator who disagrees can still queue it.
  #
  # Returns nil when nothing claims the URL, meaning "ask the model".
  def url_claim_verdicts
    claims = url_claims
    return nil if claims.empty?

    url = @source.url.to_s

    claimants = @skills.select { |s| claims.key?(s.id) }.map(&:name).to_sentence
    Rails.logger.info("SkillTriage: #{claimants} claim(s) #{url} by URL pattern; no triage call made")

    @skills.map do |skill|
      pattern = claims[skill.id]
      reason = if pattern
        "URL matches /#{pattern}/ — claimed by pattern, no triage call needed."
      else
        "Skipped: #{claimants} claim#{'s' if claims.size == 1} this URL by pattern."
      end

      Verdict.new(skill: skill, applies: !pattern.nil?, reason: reason)
    end
  end

  # { skill id => matching pattern } for every skill that claims this URL.
  def url_claims
    url = @source&.url.to_s
    return {} if url.blank?

    @skills.each_with_object({}) do |skill, memo|
      pattern = skill.url_pattern_matching(url)
      memo[skill.id] = pattern if pattern
    end
  end

  # The skills that would take this URL without a call. Empty means the model
  # gets asked.
  def url_claimants
    claims = url_claims
    @skills.select { |skill| claims.key?(skill.id) }
  end

  def page_excerpt
    @source&.source_data&.order(:created_at)&.last&.text.to_s.strip.truncate(EXCERPT_LIMIT)
  end

  def ask(excerpt)
    chat = Chat.create!(model: triage_model)
    chat.with_instructions(instructions)
    chat.with_schema(response_schema)
    chat.ask(prompt_for(excerpt)).content
  end

  def configuration
    @configuration ||= TriageConfiguration.current
  end

  # An explicit `model:` still wins — an evaluation asking for a specific model
  # is not asking what triage is configured to use.
  def triage_model
    @model || configuration.effective_model
  end

  def instructions
    configuration.effective_instructions
  end

  def prompt_for(excerpt)
    <<~TEXT
      URL: #{@source&.url}

      SKILLS
      #{skill_descriptions}

      PAGE EXCERPT (first #{EXCERPT_LIMIT} characters of the page's text)
      ---
      #{excerpt}
      ---
    TEXT
  end

  def skill_descriptions
    @skills.map do |skill|
      "- id #{skill.id} | #{skill.name}\n  applicability: #{skill.applicability}"
    end.join("\n")
  end

  def response_schema
    RubyLLM::Schema.create do
      array :verdicts do
        object do
          integer :skill_id, description: "The id of the skill being judged."
          boolean :applies, description: "Whether this skill is worth running on this page."
          string :reason, description: "One line explaining the decision."
        end
      end
    end
  end

  def parse(raw)
    entries = extract_entries(raw)
    return fail_open("triage returned no usable verdicts") if entries.blank?

    by_id = @skills.index_by(&:id)
    verdicts = entries.filter_map do |entry|
      skill = by_id[entry["skill_id"] || entry[:skill_id]]
      next unless skill

      Verdict.new(skill: skill, applies: !!(entry["applies"] || entry[:applies]),
                  reason: (entry["reason"] || entry[:reason]).to_s)
    end

    return fail_open("triage named no known skills") if verdicts.empty?

    Result.new(verdicts: verdicts, failed: false)
  end

  def extract_entries(raw)
    parsed = raw.is_a?(String) ? JSON.parse(raw) : raw
    return nil unless parsed.is_a?(Hash)

    parsed["verdicts"] || parsed[:verdicts]
  rescue JSON::ParserError
    nil
  end

  # Triage must never silently drop work: if we cannot tell which skills apply,
  # recommend all of them and say why. A wasted call is recoverable; a page
  # quietly never processed is not.
  def fail_open(reason)
    message = "Triage could not decide (#{reason}); recommending every candidate skill."
    Rails.logger.warn("SkillTriage: #{message} source ##{@source&.id}")

    Result.new(
      verdicts: @skills.map { |s| Verdict.new(skill: s, applies: true, reason: message) },
      failed: true,
      error: message
    )
  end
end
