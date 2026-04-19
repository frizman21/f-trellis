class SourcesController < ApplicationController
  def index
    @sources = Source.order(created_at: :desc).page(params[:page]).per(25)
  end

  def show
    @source = Source.find(params[:id])
  end

  def new
    @source = Source.new
  end

  def create
    @source = Source.new(source_params)

    if @source.save
      redirect_to source_path(@source), notice: "Source ##{@source.id} created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def fetch
    source = Source.find(params[:id])

    if source.status == "new"
      FetchSourceJob.perform_later(source)
      redirect_to source_path(source), notice: "Fetch job queued for source ##{source.id}."
    else
      redirect_to source_path(source),
                  alert: "Source ##{source.id} is #{source.status}; only sources in status new can be fetched."
    end
  end

  private

  def source_params
    params.require(:source).permit(:url, :description)
  end
end
