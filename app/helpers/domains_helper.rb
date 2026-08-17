module DomainsHelper
  # Same convention as report_status_cell in SourceProcessingReportsHelper —
  # a coloured badge for a state — rather than a second way of showing the
  # same idea.
  OUTCOME_BADGE_CLASSES = {
    "ok"          => "bg-success",
    "skipped"     => "bg-secondary",
    "unusable"    => "bg-warning text-dark",
    "http_error"  => "bg-danger",
    "no_response" => "bg-danger"
  }.freeze

  # What started the fetch. Muted because it is context for the row, not its
  # subject — the outcome is what the eye should land on.
  TRIGGER_LABELS = {
    "crawl"   => "Crawl",
    "manual"  => "By hand",
    "initial" => "On create"
  }.freeze

  def fetch_outcome_badge(record)
    tag.span(record.outcome.to_s.humanize,
             class: "badge #{OUTCOME_BADGE_CLASSES.fetch(record.outcome, 'bg-secondary')}")
  end

  def fetch_trigger_label(record)
    tag.span(TRIGGER_LABELS.fetch(record.trigger, record.trigger.to_s.humanize),
             class: "text-muted small")
  end

  # A record with no status is not missing data — nothing came back to have one.
  def fetch_status_code(record)
    return record.status_code.to_s if record.status_code.present?

    tag.span("—", class: "text-muted", title: "no response, so no status")
  end
end
