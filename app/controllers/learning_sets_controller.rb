class LearningSetsController < ApplicationController
  def index
    @learning_sets = LearningSet.left_joins(:learning_set_sources)
                                .select("learning_sets.*, COUNT(learning_set_sources.id) AS source_count")
                                .group("learning_sets.id")
                                .order(:name)
  end

  def show
    @learning_set = LearningSet.find(params[:id])
    @sources = @learning_set.sources.includes(:domain).order(:id)
  end

  def new
    @learning_set = LearningSet.new
  end

  def create
    @learning_set = LearningSet.new(learning_set_params)

    if @learning_set.save
      redirect_to learning_set_path(@learning_set), notice: "Learning set \"#{@learning_set.name}\" created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @learning_set = LearningSet.find(params[:id])
  end

  def update
    @learning_set = LearningSet.find(params[:id])

    if @learning_set.update(learning_set_params)
      redirect_to learning_set_path(@learning_set), notice: "Learning set \"#{@learning_set.name}\" updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    learning_set = LearningSet.find(params[:id])

    if learning_set.destroy
      redirect_to learning_sets_path,
                  notice: "Learning set \"#{learning_set.name}\" deleted. Its sources were left in place."
    else
      # An evaluation points at this set; deleting it would leave that evaluation
      # holding results with no record of which pages produced them.
      redirect_to learning_set_path(learning_set),
                  alert: learning_set.errors.full_messages.to_sentence
    end
  end

  # Add a page by URL, reusing the existing source when the URL is already known.
  def add_source
    learning_set = LearningSet.find(params[:id])
    outcome = learning_set.add_url(params[:url])

    if outcome.invalid?
      redirect_to learning_set_path(learning_set), alert: outcome.message
    else
      redirect_to learning_set_path(learning_set), notice: outcome.message
    end
  end

  # Drop a page from the set. The source itself stays — other sets, reports and
  # its fetched content still refer to it.
  def remove_source
    learning_set = LearningSet.find(params[:id])
    membership = learning_set.learning_set_sources.find_by(source_id: params[:source_id])
    membership&.destroy

    redirect_to learning_set_path(learning_set),
                notice: membership ? "Removed from #{learning_set.name}. The source itself was kept." :
                                     "That source was not in #{learning_set.name}."
  end

  private

  def learning_set_params
    params.require(:learning_set).permit(:name, :description)
  end
end
