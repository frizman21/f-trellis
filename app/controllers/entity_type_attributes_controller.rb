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

  # Retiring rather than deleting: the attribute stops being offered and keeps
  # everything recorded under it.
  def toggle_disabled
    @attribute = find_attribute
    @attribute.update!(is_disabled: !@attribute.is_disabled?)
    state = @attribute.is_disabled? ? "disabled" : "enabled"

    redirect_to project_entity_type_path(@project, @entity_type),
                notice: "Attribute \"#{@attribute.name}\" #{state}."
  end

  def destroy
    @attribute = find_attribute

    if @attribute.destroy
      redirect_to project_entity_type_path(@project, @entity_type),
                  notice: "Attribute \"#{@attribute.name}\" deleted."
    else
      # Used attributes are retired, not deleted — the values recorded under
      # them are knowledge, not schema.
      redirect_to project_entity_type_path(@project, @entity_type),
                  alert: "\"#{@attribute.name}\" has values recorded against it. " \
                         "Disable it instead of deleting it."
    end
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
    params.require(:entity_type_attribute).permit(:name, :value_type, :is_displayed_on_index)
  end
end
