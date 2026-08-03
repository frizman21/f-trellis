# The triage step's two settable inputs — the instructions it judges
# applicability against, and the model it spends — plus a read-only rendering of
# the prompt a real call builds from them.
#
# Singular: there is one triage step, so there is one configuration.
class TriageConfigurationsController < ApplicationController
  def show
    load_page
  end

  def update
    @configuration = TriageConfiguration.current

    if @configuration.update(configuration_params)
      redirect_to triage_configuration_path, notice: update_notice
    else
      load_page
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_page
    @configuration ||= TriageConfiguration.current
    @models = Model.selectable
    @skills = Skill.triageable
    @preview_source = preview_source
    @preview = SkillTriage.preview(source: @preview_source, skills: @skills)
  end

  # The example is only worth reading if it is built from a real page, so this
  # takes the most recently fetched source. Nil is a normal answer on a fresh
  # install — the preview then renders the skill list against a placeholder
  # excerpt and says as much.
  def preview_source
    Source.where(id: SourceDatum.select(:source_id))
          .order(created_at: :desc)
          .first
  end

  def update_notice
    parts = []
    parts << (@configuration.instructions_configured? ? "Instructions saved" : "Instructions reset to the default")
    parts << if @configuration.model_configured?
      "triage will run on #{@configuration.model.model_id}"
    else
      "no model pinned — triage falls back to the first selectable model"
    end

    "#{parts.join('; ')}."
  end

  def configuration_params
    params.require(:triage_configuration).permit(:instructions, :model_id)
  end
end
