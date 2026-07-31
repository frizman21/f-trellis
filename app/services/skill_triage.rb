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
class SkillTriage
  # Enough of a page to tell what kind of page it is. Triage is a routing
  # decision, not an extraction, so it does not need the whole document — and
  # sending the whole document would defeat the point.
  EXCERPT_LIMIT = 4_000

  Verdict = Struct.new(:skill, :applies, :reason, keyword_init: true)

  Result = Struct.new(:verdicts, :failed, :error, keyword_init: true) do
    def recommended = verdicts.select(&:applies)
    def skipped     = verdicts.reject(&:applies)
    def failed?     = failed
  end

  def self.call(source:, skills: nil, model: nil)
    new(source: source, skills: skills, model: model).call
  end

  def initialize(source:, skills: nil, model: nil)
    @source = source
    @skills = (skills || Skill.triageable).to_a
    @model  = model
  end

  def call
    return Result.new(verdicts: [], failed: false) if @skills.empty?

    excerpt = page_excerpt
    return fail_open("the source has no extractable text") if excerpt.blank?

    parse(ask(excerpt))
  rescue StandardError => e
    Rails.logger.error("SkillTriage failed for source ##{@source&.id}: #{e.class}: #{e.message}")
    fail_open("#{e.class}: #{e.message}")
  end

  private

  def page_excerpt
    @source&.source_data&.order(:created_at)&.last&.text.to_s.strip.truncate(EXCERPT_LIMIT)
  end

  def ask(excerpt)
    chat = Chat.create!(model: triage_model)
    chat.with_instructions(instructions)
    chat.with_schema(response_schema)
    chat.ask(prompt_for(excerpt)).content
  end

  def triage_model
    @model || Model.selectable.first
  end

  def instructions
    <<~TEXT
      You route pages to extraction skills. For each skill you are given, decide
      whether it is worth running against the page shown.

      Judge only against the skill's stated applicability. A skill that would
      find nothing, or would find only incidental mentions, does not apply —
      say so. Running a skill that does not apply wastes a model call, so do
      not include a skill just because it is loosely related.

      Return a verdict for every skill id you were given, and no others.
    TEXT
  end

  def prompt_for(excerpt)
    <<~TEXT
      URL: #{@source.url}

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
