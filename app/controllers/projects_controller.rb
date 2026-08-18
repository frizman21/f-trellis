class ProjectsController < ApplicationController
  def index
    @projects = Project.order(:name)
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
