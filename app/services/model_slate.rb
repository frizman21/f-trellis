# Picks the models an evaluation should run, given what you are trying to learn.
#
# The registry offers 155 models. Which ones go into an evaluation decides both
# what it costs — input prices span three thousand-fold — and whether it answers
# anything, and a scrollable alphabetical list of checkboxes helps with neither.
# So the form asks for an objective instead, and this turns the objective into a
# set of models with a reason attached to each.
#
# Pure: it reads the registry and writes nothing. The caller decides what to do
# with the suggestions, and the person at the form can always overrule them.
class ModelSlate
  OBJECTIVES = %w[cheapest survey ladder copy].freeze
  DEFAULT_COUNT = 5
  MAX_COUNT = 25

  # One model and why it is here. The reason is the whole point — a set of
  # models with no explanation is the checkbox list again, just shorter.
  Suggestion = Struct.new(:model, :reason, keyword_init: true) do
    def model_id = model.model_id
  end

  def self.call(objective:, models:, baseline: nil, count: nil, provider: nil, source_evaluation: nil)
    new(objective: objective, models: models, baseline: baseline, count: count,
        provider: provider, source_evaluation: source_evaluation).call
  end

  def initialize(objective:, models:, baseline: nil, count: nil, provider: nil, source_evaluation: nil)
    @objective = objective.to_s
    @models = Array(models)
    @baseline = baseline
    @count = clamp_count(count)
    @provider = provider.presence
    @source_evaluation = source_evaluation
  end

  def call
    return [] unless OBJECTIVES.include?(@objective)

    with_baseline(send(:"#{@objective}_suggestions"))
  end

  private

  # Models any objective is allowed to reach for: ones that can do the job, with
  # each set of duplicate weights collapsed to a single id.
  def candidates
    @candidates ||= dedupe_snapshots(@models.select(&:chat_capable?))
  end

  # `claude-3-5-sonnet-latest` and `claude-3-5-sonnet-20241022` are the same
  # weights under two names; running both spends twice to learn once. Keeps the
  # bare alias where there is one — it is the id a person recognises and the one
  # that keeps pointing at the current release — and otherwise the newest
  # snapshot.
  def dedupe_snapshots(models)
    models.group_by { |m| [ m.provider, m.snapshot_key ] }.map do |_key, group|
      group.min_by { |m| [ m.dated_snapshot? ? 1 : 0, -(m.model_created_at&.to_i || 0), m.model_id ] }
    end
  end

  # The baseline is what everything else is compared against, so a run without
  # it produces columns and nothing to read them against. Prepended rather than
  # appended so it reads first, and never duplicated if an objective picked it.
  def with_baseline(suggestions)
    return suggestions if @baseline.nil?

    rest = suggestions.reject { |s| s.model.id == @baseline.id }
    [ Suggestion.new(model: @baseline, reason: "baseline") ] + rest
  end

  def cheapest_suggestions
    priced(candidates).first(@count || DEFAULT_COUNT).map do |model|
      Suggestion.new(model: model, reason: "cheapest text models")
    end
  end

  # One model per family, so the run covers the range of what is on offer rather
  # than one corner of it. Families come cheapest-first by median price, which
  # puts the affordable breadth at the top when a count trims the list.
  def survey_suggestions
    families = families_by_median_price(candidates)
    families = families.first(@count) if @count

    families.map do |family, members|
      Suggestion.new(model: representative(members), reason: "represents #{family}")
    end
  end

  # The same shape as a survey, held to one provider: what you run when the
  # question is "how far down this provider's range can I go before it breaks?"
  def ladder_suggestions
    within_provider = candidates.select { |m| @provider.nil? || m.provider == @provider }
    families = families_by_median_price(within_provider)
    families = families.first(@count) if @count

    families.map do |family, members|
      Suggestion.new(model: representative(members), reason: "the #{rung_name(family)} rung")
    end
  end

  # The model set of an evaluation that already answered something, so the next
  # question is asked of the same models and the two runs are comparable.
  def copy_suggestions
    return [] if @source_evaluation.nil?

    wanted = @source_evaluation.models.map(&:id).to_set
    candidates.select { |m| wanted.include?(m.id) }
              .sort_by { |m| [ m.provider, m.model_id ] }
              .map { |m| Suggestion.new(model: m, reason: "same as Evaluation ##{@source_evaluation.id}") }
  end

  # Cheapest first. A model with no published price sorts last rather than free:
  # unknown is not zero, and putting it first would make "cheapest" a lie.
  def priced(models)
    models.sort_by { |m| [ m.input_price_per_million.nil? ? 1 : 0, m.input_price_per_million || 0, m.model_id ] }
  end

  # [[family, members], …], cheapest family first. Median rather than mean so a
  # single expensive snapshot does not push a whole family down the list.
  #
  # Models the registry assigns no family to are left out: "one per family" only
  # says something when there is a family, and treating each of them as a family
  # of one turns a 13-model survey into a 31-model one. They stay listed and
  # tickable on the form — a survey just does not reach for them.
  def families_by_median_price(models)
    models.select { |m| m.family.present? }
          .group_by(&:family)
          .sort_by { |family, members| [ median_price(members), family ] }
  end

  def median_price(models)
    prices = models.filter_map(&:input_price_per_million).sort
    return Float::INFINITY if prices.empty?

    prices[(prices.size - 1) / 2]
  end

  # The family's median-priced member, leaning cheap on an even count. A survey
  # wants a typical member — taking the cheapest of every family would just be
  # the cheapest objective again under another name.
  def representative(models)
    ordered = priced(models)
    ordered[(ordered.size - 1) / 2]
  end

  # `gpt-mini` → "mini", `claude-sonnet` → "sonnet", `o` → "o". The last segment
  # of the family name is what people call the rung.
  def rung_name(family)
    family.to_s.split("-").last.presence || family.to_s
  end

  def clamp_count(value)
    return nil if value.blank?

    [ [ value.to_i, 1 ].max, MAX_COUNT ].min
  end
end
