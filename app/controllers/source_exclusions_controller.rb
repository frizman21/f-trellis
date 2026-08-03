class SourceExclusionsController < ApplicationController
  before_action :set_source_exclusion, only: [ :edit, :update, :destroy ]

  def index
    @source_exclusions = SourceExclusion.ordered
  end

  def new
    @source_exclusion = SourceExclusion.new
  end

  def create
    @source_exclusion = SourceExclusion.new(source_exclusion_params)

    if @source_exclusion.save
      redirect_to source_exclusions_path,
                  notice: "Exclusion #{@source_exclusion.pattern} created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @source_exclusion.update(source_exclusion_params)
      redirect_to source_exclusions_path,
                  notice: "Exclusion #{@source_exclusion.pattern} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @source_exclusion.destroy
    redirect_to source_exclusions_path,
                notice: "Exclusion #{@source_exclusion.pattern} deleted."
  end

  private

  def set_source_exclusion
    @source_exclusion = SourceExclusion.find(params[:id])
  end

  def source_exclusion_params
    params.require(:source_exclusion).permit(:pattern, :description, :is_enabled)
  end
end
