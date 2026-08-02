require "test_helper"

class ModelSlateTest < ActiveSupport::TestCase
  # Every model gets the same `last_seen_at`: `Model.current` keeps only the rows
  # stamped by the most recent refresh, so a per-row Time.current would leave the
  # last one built as the only selectable model.
  STAMP = Time.utc(2026, 7, 31, 12, 0, 0)

  def build_model(model_id, price: nil, family: nil, provider: "openai", outputs: [ "text" ],
                  context_window: 128_000, created: nil)
    Model.create!(
      provider: provider, model_id: model_id, name: model_id, family: family,
      last_seen_at: STAMP, context_window: context_window,
      model_created_at: created,
      modalities: { "input" => [ "text" ], "output" => outputs },
      pricing: price.nil? ? {} : { "text_tokens" => { "standard" => { "input_per_million" => price } } }
    )
  end

  setup do
    Model.delete_all

    @nano  = build_model("gpt-nano-1",   price: 0.1,  family: "gpt-nano")
    @mini  = build_model("gpt-mini-1",   price: 0.5,  family: "gpt-mini")
    @full  = build_model("gpt-full-1",   price: 5.0,  family: "gpt")
    @haiku = build_model("claude-haiku-1", price: 0.25, family: "claude-haiku", provider: "anthropic")
    @opus  = build_model("claude-opus-1",  price: 15.0, family: "claude-opus",  provider: "anthropic")
    @embeddings = build_model("text-embedding-9", price: 0.01, family: "text-embedding",
                              outputs: [ "embeddings" ])
    @all = Model.selectable.to_a
  end

  def ids(suggestions) = suggestions.map { |s| s.model.model_id }

  test "cheapest returns the least expensive models in price order" do
    suggestions = ModelSlate.call(objective: "cheapest", models: @all, count: 3)

    assert_equal [ "gpt-nano-1", "claude-haiku-1", "gpt-mini-1" ], ids(suggestions)
    assert_equal [ "cheapest text models" ], suggestions.map(&:reason).uniq
  end

  test "cheapest never reaches for a model that cannot return text" do
    suggestions = ModelSlate.call(objective: "cheapest", models: @all, count: 6)

    assert_not_includes ids(suggestions), "text-embedding-9"
  end

  test "a model with no published price sorts last, not free" do
    unpriced = build_model("gpt-unpriced", family: "gpt-mystery")

    suggestions = ModelSlate.call(objective: "cheapest", models: Model.selectable.to_a, count: 6)

    assert_equal unpriced.model_id, ids(suggestions).last
  end

  test "survey returns one model per family, cheapest family first" do
    suggestions = ModelSlate.call(objective: "survey", models: @all)

    assert_equal [ "gpt-nano-1", "claude-haiku-1", "gpt-mini-1", "gpt-full-1", "claude-opus-1" ],
                 ids(suggestions)
    assert_includes suggestions.map(&:reason), "represents claude-haiku"
  end

  test "survey picks a representative rather than the cheapest of each family" do
    build_model("gpt-mini-cheap", price: 0.2, family: "gpt-mini")
    build_model("gpt-mini-dear",  price: 2.0, family: "gpt-mini")

    suggestions = ModelSlate.call(objective: "survey", models: Model.selectable.to_a)
    mini = suggestions.detect { |s| s.reason == "represents gpt-mini" }

    assert_equal "gpt-mini-1", mini.model.model_id
  end

  test "ladder covers one provider, one model per rung, in price order" do
    suggestions = ModelSlate.call(objective: "ladder", models: @all, provider: "anthropic")

    assert_equal [ "claude-haiku-1", "claude-opus-1" ], ids(suggestions)
    assert_equal [ "the haiku rung", "the opus rung" ], suggestions.map(&:reason)
  end

  test "copy mirrors the model set of another evaluation" do
    other = evaluation_with(models: [ @nano, @opus ])

    suggestions = ModelSlate.call(objective: "copy", models: @all, source_evaluation: other)

    assert_equal [ "claude-opus-1", "gpt-nano-1" ], ids(suggestions).sort
    assert_equal [ "same as Evaluation ##{other.id}" ], suggestions.map(&:reason).uniq
  end

  test "copy with nothing to copy from returns nothing" do
    assert_empty ModelSlate.call(objective: "copy", models: @all, source_evaluation: nil)
  end

  test "every objective includes the baseline, first and once" do
    ModelSlate::OBJECTIVES.each do |objective|
      suggestions = ModelSlate.call(objective: objective, models: @all, baseline: @nano,
                                    provider: "openai", count: 4,
                                    source_evaluation: evaluation_with(models: [ @nano, @mini ]))

      assert_equal "gpt-nano-1", suggestions.first.model.model_id, objective
      assert_equal "baseline", suggestions.first.reason, objective
      assert_equal 1, ids(suggestions).count("gpt-nano-1"), objective
    end
  end

  test "every objective drops models that cannot return text" do
    cheap_embeddings = build_model("text-embedding-cheap", price: 0.001, family: "text-embedding",
                                   outputs: [ "embeddings" ])
    models = Model.selectable.to_a

    ModelSlate::OBJECTIVES.each do |objective|
      suggestions = ModelSlate.call(objective: objective, models: models, provider: "openai",
                                    source_evaluation: evaluation_with(models: [ @nano, cheap_embeddings ]))

      assert_not_includes ids(suggestions), cheap_embeddings.model_id, objective
    end
  end

  test "an alias wins over its dated snapshot, which is the same weights billed twice" do
    build_model("gpt-nano-1-2025-08-07", price: 0.1, family: nil)

    suggestions = ModelSlate.call(objective: "cheapest", models: Model.selectable.to_a, count: 6)

    assert_includes ids(suggestions), "gpt-nano-1"
    assert_not_includes ids(suggestions), "gpt-nano-1-2025-08-07"
  end

  test "with no alias present the newest snapshot stands in for the family" do
    Model.delete_all
    build_model("claude-sonnet-20240620", price: 3.0, family: "claude-sonnet",
                provider: "anthropic", created: 1.year.ago)
    build_model("claude-sonnet-20241022", price: 3.0, family: "claude-sonnet",
                provider: "anthropic", created: 1.month.ago)

    suggestions = ModelSlate.call(objective: "cheapest", models: Model.selectable.to_a, count: 5)

    assert_equal [ "claude-sonnet-20241022" ], ids(suggestions)
  end

  test "an unknown objective suggests nothing rather than guessing" do
    assert_empty ModelSlate.call(objective: "whatever", models: @all)
  end

  test "count is clamped so a pasted number cannot ask for the whole registry" do
    suggestions = ModelSlate.call(objective: "cheapest", models: @all, count: 10_000)

    assert_operator suggestions.size, :<=, ModelSlate::MAX_COUNT
  end

  private

  def evaluation_with(models:)
    skill = Skill.create!(name: "Slate skill #{SecureRandom.hex(4)}")
    skill.skill_revisions.create!(content: "Pull the orgs.")
    evaluation = SkillEvaluation.create!(
      name: "Slate evaluation", skill: skill, base_model: models.first,
      learning_set: LearningSet.create!(name: "Slate set #{SecureRandom.hex(4)}")
    )
    evaluation.models = models
    evaluation
  end
end
