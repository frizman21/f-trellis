# Whether a project can run its extraction prompt over a source, and if not, why.
#
# One place rather than two: the button asks so it can disable itself with a
# reason, and the controller asks so a hand-made request cannot skip the check.
# Two copies of "can this run?" would eventually disagree, and the one that
# disagreed would be the one that let a bad run through.
class ExtractionReadiness
  def initialize(project, source)
    @project = project
    @source = source
  end

  attr_reader :project, :source

  # nil when it can run; otherwise the sentence to show.
  def reason
    return "This project has no default model. Choose one on the project's edit page." if project.default_model.nil?
    return "This page has no fetched content yet." if source.latest_text.blank?
    return "This project's structure defines nothing to extract." if ExtractionPrompt.new(project).empty?
    return "An extraction is already running for this page." if in_flight?

    nil
  end

  def runnable? = reason.nil?

  # `live` rather than `in_flight`: a run whose worker died is in flight forever,
  # and counting it would take this page out of service permanently. Reading
  # this question is what unblocks the button — no write, and no click.
  def in_flight?
    project.extraction_runs.where(source: source).live.exists?
  end
end
