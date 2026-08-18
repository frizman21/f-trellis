# Attributes are always reached through the type that owns them — an attribute
# has no meaning apart from it — and that type through its project.
class EntityTypeAttributesController < ApplicationController
  before_action :set_entity_type

  def new
    @attribute = @entity_type.entity_type_attributes.new
  end

  def create
    @attribute = @entity_type.entity_type_attributes.new(attribute_params)

    if @attribute.save
      redirect_to project_entity_type_path(@project, @entity_type),
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
      redirect_to project_entity_type_path(@project, @entity_type),
                  notice: "Attribute \"#{@attribute.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @attribute = find_attribute
    @attribute.destroy

    redirect_to project_entity_type_path(@project, @entity_type),
                notice: "Attribute \"#{@attribute.name}\" deleted."
  end

  private

  def set_entity_type
    @project = Project.find(params[:project_id])
    @entity_type = @project.entity_types.find(params[:entity_type_id])
  end

  def find_attribute
    @entity_type.entity_type_attributes.find(params[:id])
  end

  def attribute_params
    params.require(:entity_type_attribute).permit(:name, :value_type)
  end
end
