class SourceDataController < ApplicationController
  def download
    datum = SourceDatum.find(params[:id])

    send_data datum.data,
              type: datum.content_type.presence || "application/octet-stream",
              filename: filename_for(datum),
              disposition: "attachment"
  end

  private

  def filename_for(datum)
    extension = {
      "application/zip" => ".zip",
      "text/html"       => ".html",
      "application/pdf" => ".pdf"
    }.fetch(datum.content_type, "")

    "source-#{datum.source_id}-datum-#{datum.id}#{extension}"
  end
end
