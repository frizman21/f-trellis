require "zip"

class SourceDataController < ApplicationController
  # The legacy content type: every row written before the payload's own type was
  # recorded says this, and none of them can be backfilled — the original header
  # was never captured.
  ZIPPED = "application/zip".freeze

  # The zip is how the payload is stored, not what it is. Since content_type
  # started describing the page inside the container, a download hands back the
  # page. Rows written before that change carry the container's own type and are
  # still sent as the zip they are.
  def download
    datum = SourceDatum.find(params[:id])

    if datum.content_type == ZIPPED
      send_data datum.data, type: ZIPPED, filename: filename_for(datum), disposition: "attachment"
    elsif datum.binary?
      # A document goes back byte-for-byte. Through the branch below it would be
      # sent as datum.html.to_s, which is now nil for a binary payload and was
      # mojibake before that — either way a file that will not open.
      send_data datum.raw_bytes.to_s,
                type: datum.content_type,
                filename: filename_for(datum),
                disposition: "attachment"
    else
      send_data datum.html.to_s,
                type: datum.content_type.presence || "application/octet-stream",
                filename: filename_for(datum),
                disposition: "attachment"
    end
  end

  # Unzip the payload, pull out its links (the same extraction CrawlJob uses),
  # create a Source for every link we do not already have, and record a
  # SourceLink edge for every link — new or already known. Unlike the crawl
  # this does not fetch anything — the new sources are left in status "new".
  def extract_links
    @datum  = SourceDatum.find(params[:id])
    @source = @datum.source

    begin
      @links = @datum.extract_links
    rescue StandardError => e
      Rails.logger.error("SourceDataController#extract_links: could not read datum ##{@datum.id}: #{e.class}: #{e.message}")
      @links = nil
      @error = "Could not unzip this payload (#{e.class}: #{e.message})."
      return
    end

    create_sources_for(@links.internal + @links.external)
  end

  private

  def create_sources_for(urls)
    @created   = []
    @skipped   = []
    @failed    = []
    @new_links = 0

    urls.uniq.each do |url|
      if url == @source.url
        @skipped << url
        next
      end

      target = Source.find_by(url: url)

      if target
        @skipped << url
      else
        target = Source.new(url: url,
                            parent_source: @source,
                            description: "Discovered by link extraction from #{@source.url}")

        unless target.save
          @failed << [ url, target.errors.full_messages.to_sentence ]
          next
        end

        @created << target
      end

      link = SourceLink.record(from: @source, to: target, datum: @datum)
      @new_links += 1 if link&.previously_new_record?
    end
  end

  def filename_for(datum)
    extension = {
      "application/zip" => ".zip",
      "text/html"       => ".html",
      "application/pdf" => ".pdf"
    }.fetch(datum.content_type, "")

    "source-#{datum.source_id}-datum-#{datum.id}#{extension}"
  end
end
