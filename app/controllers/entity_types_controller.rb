class EntityTypesController < ApplicationController
  def index
    @entity_types = EntityType.all
  end

  def show
    @entity_type = EntityType.find(params[:id])
  end

  def new
    @entity_type = EntityType.new
  end

  def create
    @entity_type = EntityType.new(entity_type_params)

    if @entity_type.save
      redirect_to entity_type_path(@entity_type), notice: "Entity type \"#{@entity_type.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @entity_type = EntityType.find(params[:id])
  end

  def update
    @entity_type = EntityType.find(params[:id])

    if @entity_type.update(entity_type_params)
      redirect_to entity_type_path(@entity_type), notice: "Entity type \"#{@entity_type.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @entity_type = EntityType.find(params[:id])

    if @entity_type.destroy
      redirect_to entity_types_path, notice: "Entity type \"#{@entity_type.name}\" deleted."
    else
      # restrict_with_error: a type with entities of it still in the system is
      # not something to cascade away silently.
      redirect_to entity_type_path(@entity_type), alert: @entity_type.errors.full_messages.to_sentence
    end
  end

  private

  def entity_type_params
    params.require(:entity_type).permit(:name, :description)
  end
end
