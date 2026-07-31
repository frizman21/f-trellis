# Turns an evaluation's configuration into runnable work: one pending result per
# (page, model) pair, and one job each.
#
# Pairs already run at the skill's current revision are skipped rather than paid
# for twice — a run is one model call per pair, so pressing the button again on
# a 20-page, 4-model evaluation would otherwise cost 80 calls to learn nothing.
# Editing the skill creates a revision, which makes every pair runnable again.
class SkillEvaluationRunner
  Outcome = Struct.new(:queued, :skipped, :error, keyword_init: true) do
    def queued?  = queued.any?
    def blocked? = error.present?

    def summary
      return error if blocked?

      parts = []
      parts << "Queued #{queued.size} #{'run'.pluralize(queued.size)}." if queued.any?
      if skipped.any?
        by_reason = skipped.group_by(&:last).transform_values(&:size)
        parts << "Skipped #{skipped.size}: " +
                 by_reason.map { |reason, count| "#{count} #{reason}" }.to_sentence + "."
      end
      parts << "Nothing to run." if parts.empty?
      parts.join(" ")
    end
  end

  def self.call(evaluation:)
    new(evaluation: evaluation).call
  end

  def initialize(evaluation:)
    @evaluation = evaluation
  end

  def call
    revision = @evaluation.current_skill_revision
    return blocked("#{@evaluation.skill.name} has no revisions to run.") if revision.nil?

    sources = @evaluation.sources.order(:id).to_a
    models  = @evaluation.models.order(:provider, :model_id).to_a
    if sources.empty?
      return blocked("#{@evaluation.learning_set.name} has no sources; add a page to the set before running.")
    end
    return blocked("Select at least one model before running.") if models.empty?

    queued  = []
    skipped = []

    sources.each do |source|
      if source.latest_text.blank?
        models.each { |model| skipped << [ source, model, "with no fetched content" ] }
        next
      end

      models.each do |model|
        result = build_result(source, model, revision)

        if result.nil?
          skipped << [ source, model, "already run at this revision" ]
        elsif result.save
          RunSkillEvaluationJob.perform_later(result)
          queued << result
        else
          skipped << [ source, model, result.errors.full_messages.to_sentence ]
        end
      end
    end

    Outcome.new(queued: queued, skipped: skipped)
  end

  private

  def build_result(source, model, revision)
    existing = @evaluation.skill_evaluation_results
                          .find_by(source: source, model: model, skill_revision: revision)
    return nil if existing

    SkillEvaluationResult.new(skill_evaluation: @evaluation, source: source, model: model,
                              skill_revision: revision, status: "pending")
  end

  def blocked(message)
    Outcome.new(queued: [], skipped: [], error: message)
  end
end
