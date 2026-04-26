class ResearchStartingPointsController < ApplicationController
  before_action :set_research_starting_point, only: [:show, :edit, :update, :destroy]

  def index
    @research_starting_points = ResearchStartingPoint.order(created_at: :desc).page(params[:page]).per(25)
  end

  def show
  end

  def new
    @research_starting_point = ResearchStartingPoint.new(frequency: "weekly")
  end

  def create
    @research_starting_point = ResearchStartingPoint.new(research_starting_point_params)

    if @research_starting_point.save
      redirect_to research_starting_point_path(@research_starting_point),
                  notice: "Research starting point ##{@research_starting_point.id} created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @research_starting_point.update(research_starting_point_params)
      redirect_to research_starting_point_path(@research_starting_point),
                  notice: "Research starting point ##{@research_starting_point.id} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @research_starting_point.destroy
    redirect_to research_starting_points_path,
                notice: "Research starting point ##{@research_starting_point.id} deleted."
  end

  private

  def set_research_starting_point
    @research_starting_point = ResearchStartingPoint.find(params[:id])
  end

  def research_starting_point_params
    params.require(:research_starting_point).permit(:url, :frequency, :description, :is_enabled)
  end
end
