class SkillRevisionsController < ApplicationController
  def show
    @revision = SkillRevision.find(params[:id])
    @skill = @revision.skill
  end
end
