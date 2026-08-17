class SourceImportsController < ApplicationController
  def index
    @imports = SourceImport.recent.page(params[:page]).per(25)
  end

  def new
    @import = SourceImport.new
  end

  # Nothing about the work happens here. Two thousand rows means two thousand
  # inserts plus a Domain lookup each, which does not belong in a request — and
  # a timeout part way through would leave a partial import with nothing
  # recording what happened.
  def create
    @import = SourceImport.new(raw_urls: params.dig(:source_import, :raw_urls))

    if @import.save
      ImportSourcesJob.perform_later(@import)
      redirect_to source_import_path(@import), notice: "Import started."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Renders what the record says at the time it is loaded; refreshing is how
  # progress is seen. Live updates are a separate concern from getting the
  # URLs in.
  def show
    @import = SourceImport.find(params[:id])
  end
end
