module SkillEvaluationsHelper
  def evaluation_status_badge(status)
    css = case status
    when "complete" then "bg-success"
    when "running"  then "bg-info text-dark"
    when "failed"   then "bg-danger"
    else "bg-secondary"
    end

    content_tag(:span, status.to_s.capitalize, class: "badge #{css}")
  end

  RUN_STATUS_LABELS = {
    not_run: [ "Not run", "bg-secondary" ],
    running: [ "Running", "bg-info text-dark" ],
    incomplete: [ "Incomplete", "bg-warning text-dark" ],
    failed: [ "Failed", "bg-danger" ],
    complete_with_failures: [ "Complete, with failures", "bg-warning text-dark" ],
    complete: [ "Complete", "bg-success" ]
  }.freeze

  def evaluation_run_badge(status)
    label, css = RUN_STATUS_LABELS.fetch(status, [ status.to_s.humanize, "bg-secondary" ])

    content_tag(:span, label, class: "badge #{css}")
  end

  # "4 complete, 1 failed, 1 pending of 6 pairs" — zero buckets left out, so the
  # sentence says what happened rather than listing every status.
  def evaluation_progress_summary(counts, planned)
    parts = SkillEvaluationResult::STATUSES.filter_map do |status|
      count = counts[status].to_i
      "#{count} #{status}" if count.positive?
    end

    return "No runs yet of #{pluralize(planned, 'pair')}." if parts.empty?

    "#{parts.to_sentence} of #{pluralize(planned, 'pair')}."
  end

  OBJECTIVE_BUTTONS = [
    [ "cheapest", "Cheapest viable", "The N least expensive models that can do the job." ],
    [ "survey", "Survey", "One model per family, so the run covers the range on offer." ],
    [ "ladder", "Ladder", "One provider, one model per rung, cheapest first." ],
    [ "copy", "Copy an evaluation", "The same models another evaluation ran, so the two compare." ]
  ].freeze

  # A model that cannot do the job stays listed and tickable — the metadata is
  # not good enough to hide things on — but says why it is a bad idea.
  def model_capability_badge(model)
    flag = model.capability_flag
    return nil if flag.nil?

    content_tag(:span, flag, class: "badge bg-warning text-dark ms-1")
  end

  # "5 models × 8 pages = 40 runs · est. $0.38 of input at current prices".
  #
  # Input only: what a model sends back is not known before it runs, and a range
  # wide enough to be honest about output would not be worth reading.
  def evaluation_scale_summary(estimate, models)
    runs = models.size * estimate.pages
    parts = [ "#{pluralize(models.size, 'model')} × #{pluralize(estimate.pages, 'page')} = #{pluralize(runs, 'run')}" ]

    priced, unpriced = models.partition { |m| m.input_price_per_million }
    if priced.any? && estimate.tokens.positive?
      dollars = priced.sum { |m| estimate.tokens * m.input_price_per_million / 1_000_000.0 }
      parts << "est. #{number_to_currency(dollars, precision: dollars < 1 ? 2 : 0)} of input at current prices"
    end
    parts << "#{pluralize(unpriced.size, 'model')} with no published price" if unpriced.any?
    parts << "#{pluralize(estimate.unfetched_pages, 'page')} not fetched yet, and not counted" if estimate.unfetched_pages.positive?

    parts.join(" · ")
  end

  # Models whose context window cannot hold the set's largest page. Evaluation
  # sends a page whole, so these fail for a boring reason rather than a
  # revealing one, and the run tells you nothing about the model.
  def models_too_small_for(estimate, models)
    return [] unless estimate.largest_page_tokens.positive?

    models.select { |m| m.context_window.to_i.positive? && m.context_window < estimate.largest_page_tokens }
  end

  # Scoring is not implemented — a result has no number to show, and inventing
  # one would be worse than an em dash.
  def evaluation_score_label(result)
    return content_tag(:span, "—", class: "text-muted", title: "Scoring not implemented yet") if result.score.nil?

    format("%g", result.score)
  end
end
