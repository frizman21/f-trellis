class SourcesController < ApplicationController
  def index
    @sources = Source.order(created_at: :desc).page(params[:page]).per(25)
  end

  def show
    @source = Source.find(params[:id])
  end
end
