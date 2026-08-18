class RelationshipTypeAttributesController < ApplicationController
  before_action :set_relationship_type

  def new
    @attribute = @relationship_type.relationship_type_attributes.new
  end

  def create
    @attribute = @relationship_type.relationship_type_attributes.new(attribute_params)

    if @attribute.save
      redirect_to project_relationship_type_path(@project, @relationship_type),
                  notice: "Attribute \"#{@attribute.name}\" added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @attribute = find_attribute
  end

  def update
    @attribute = find_attribute

    if @attribute.update(attribute_params)
      redirect_to project_relationship_type_path(@project, @relationship_type),
                  notice: "Attribute \"#{@attribute.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @attribute = find_attribute
    @attribute.destroy

    redirect_to project_relationship_type_path(@project, @relationship_type),
                notice: "Attribute \"#{@attribute.name}\" deleted."
  end

  private

  def set_relationship_type
    @project = Project.find(params[:project_id])
    @relationship_type = @project.relationship_types.find(params[:relationship_type_id])
  end

  def find_attribute
    @relationship_type.relationship_type_attributes.find(params[:id])
  end

  def attribute_params
    params.require(:relationship_type_attribute).permit(:name, :value_type)
  end
end
