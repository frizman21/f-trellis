# Attributes are always reached through the type that owns them — an attribute
# has no meaning apart from it.
class EntityTypeAttributesController < ApplicationController
  before_action :set_entity_type

  def new
    @attribute = @entity_type.entity_type_attributes.new
  end

  def create
    @attribute = @entity_type.entity_type_attributes.new(attribute_params)

    if @attribute.save
      redirect_to entity_type_path(@entity_type), notice: "Attribute \"#{@attribute.name}\" added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @attribute = @entity_type.entity_type_attributes.find(params[:id])
  end

  def update
    @attribute = @entity_type.entity_type_attributes.find(params[:id])

    if @attribute.update(attribute_params)
      redirect_to entity_type_path(@entity_type), notice: "Attribute \"#{@attribute.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @attribute = @entity_type.entity_type_attributes.find(params[:id])
    @attribute.destroy

    redirect_to entity_type_path(@entity_type), notice: "Attribute \"#{@attribute.name}\" deleted."
  end

  private

  def set_entity_type
    @entity_type = EntityType.find(params[:entity_type_id])
  end

  def attribute_params
    params.require(:entity_type_attribute).permit(:name, :value_type)
  end
end
