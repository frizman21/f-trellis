class EntitiesController < ApplicationController
  def index
    @entities = Entity.includes(:entity_type, entity_attribute_values: :entity_type_attribute)
                      .order(:id)
                      .page(params[:page]).per(25)
  end

  def show
    @entity = Entity.includes(entity_attribute_values: :entity_type_attribute).find(params[:id])
    @rows = @entity.attribute_rows
    @relationships = @entity.relationships
                            .includes(from_entity: :entity_type, to_entity: :entity_type)
                            .order(:id)
    # For the "add a relationship" picker. Everything but this entity — an edge
    # to itself is rejected by the model, so it should not be offered either.
    @candidates = Entity.includes(:entity_type, entity_attribute_values: :entity_type_attribute)
                        .where.not(id: @entity.id)
  end

  # Creating is two steps: pick the type here, fill in its attributes on the
  # edit page. One form whose fields change with the type dropdown would need
  # JavaScript to re-render; this needs none.
  def new
    @entity = Entity.new
  end

  def create
    @entity = Entity.new(entity_params)

    if @entity.save
      redirect_to edit_entity_path(@entity), notice: "Entity created. Fill in its attributes."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @entity = Entity.find(params[:id])
    @entity.build_missing_attribute_values
  end

  def update
    @entity = Entity.find(params[:id])

    if @entity.update(entity_params)
      redirect_to entity_path(@entity), notice: "Entity updated."
    else
      @entity.build_missing_attribute_values
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @entity = Entity.find(params[:id])
    label = @entity.label
    @entity.destroy

    redirect_to entities_path, notice: "Entity \"#{label}\" deleted."
  end

  private

  def entity_params
    params.require(:entity).permit(
      :entity_type_id,
      entity_attribute_values_attributes: [ :id, :entity_type_attribute_id, :value ]
    )
  end
end
