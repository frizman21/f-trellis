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

  # Scoring is not implemented — a result has no number to show, and inventing
  # one would be worse than an em dash.
  def evaluation_score_label(result)
    return content_tag(:span, "—", class: "text-muted", title: "Scoring not implemented yet") if result.score.nil?

    format("%g", result.score)
  end
end
