class ProjectsController < ApplicationController
  def index
    # The listing shows how much each project holds on each of its two sides,
    # so the counts are loaded with it rather than one query per row.
    @projects = Project.includes(:entity_types, :entities).order(:name)
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      redirect_to projects_path, notice: "Project \"#{@project.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @project = Project.find(params[:id])
  end

  def update
    @project = Project.find(params[:id])

    if @project.update(project_params)
      redirect_to projects_path, notice: "Project \"#{@project.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def project_params
    params.require(:project).permit(:name)
  end
end
