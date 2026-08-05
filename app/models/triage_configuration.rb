# The two inputs to the triage call that are worth a person's judgement: the
# instructions it judges applicability against, and the model it spends.
#
# A singleton — there is one triage step, so there is one configuration. Both
# columns are nullable and blank means "use the default", which is what lets
# this ship without changing what triage does for anyone who never opens the
# page. See SkillTriage.
class TriageConfiguration < ApplicationRecord
  belongs_to :model, optional: true

  # A field cleared on the form is a reset, so it is stored as NULL rather than
  # as an empty string standing in for one.
  normalizes :instructions, with: ->(text) { text.strip.presence }

  # The instructions SkillTriage sent before this record existed. Kept here
  # rather than in the service so the form has something to show as the default
  # and to fall back to when the field is cleared.
  DEFAULT_INSTRUCTIONS = <<~TEXT.freeze
    You route pages to extraction skills. For each skill you are given, decide
    whether it is worth running against the page shown.

    Judge only against the skill's stated applicability. A skill that would
    find nothing, or would find only incidental mentions, does not apply —
    say so. Running a skill that does not apply wastes a model call, so do
    not include a skill just because it is loosely related.

    Return a verdict for every skill id you were given, and no others.
  TEXT

  # The one row, or an unsaved one standing in for it. Reading never writes —
  # triage and the preview both call this on paths that must not touch the
  # database, and the row is created the first time someone saves the form.
  #
  # Ordered by id so a database that somehow holds two rows keeps answering
  # with the same one rather than alternating between them.
  def self.current
    order(:id).first || new
  end

  def instructions_configured? = instructions.present?

  def model_configured? = model.present?

  def effective_instructions
    instructions.presence || DEFAULT_INSTRUCTIONS
  end

  # Falls back to the same expression SkillTriage used before this record
  # existed. That is alphabetically-first-by-id rather than cheapest, which is
  # exactly the accident this page exists to let someone correct.
  #
  # A pinned model that has since been deprecated or disabled falls back too:
  # triage runs unattended on every fetched source, so honouring the pin would
  # mean failing every one of them until somebody noticed and came here.
  def effective_model
    return model if model && !model.unusable?

    Model.selectable.first
  end
end
