module SourceProcessingReportsHelper
  STATUS_BADGE_CLASSES = {
    "complete"   => "bg-success",
    "processing" => "bg-info text-dark",
    "failed"     => "bg-danger"
  }.freeze

  # The status badge, and under it the reason the run failed when there is one.
  # Both tables that list reports — the reports index and the source page — want
  # exactly this pair, and a report that failed is useless without the reason.
  def report_status_cell(report)
    badge = tag.span(report.status.to_s.capitalize,
                     class: "badge #{STATUS_BADGE_CLASSES.fetch(report.status, 'bg-secondary')}")

    return badge if report.error.blank?

    badge + tag.div(truncate(report.error, length: 120),
                    class: "small text-danger", title: report.error)
  end
end
