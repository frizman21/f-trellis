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

  # Scoring is not implemented — a result has no number to show, and inventing
  # one would be worse than an em dash.
  def evaluation_score_label(result)
    return content_tag(:span, "—", class: "text-muted", title: "Scoring not implemented yet") if result.score.nil?

    format("%g", result.score)
  end
end
