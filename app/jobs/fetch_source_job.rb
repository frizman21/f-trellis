require "net/http"
require "zip"

class FetchSourceJob < ApplicationJob
  queue_as :default

  class SourceNotFetchable < StandardError; end

  def perform(source)
    return unless source.status == "new"

    source.update!(status: "in_work")

    html  = fetch_html(source.url)
    bytes = zip_payload(filename_for(source), html)

    SourceDatum.create!(
      source: source,
      content_type: "application/zip",
      data: bytes
    )

    source.update!(status: "complete")
  rescue StandardError => e
    source.update!(status: "failed") if source.persisted?
    Rails.logger.error("FetchSourceJob failed for source ##{source.id}: #{e.class}: #{e.message}")
    raise
  end

  private

  def fetch_html(url)
    uri = URI.parse(url)
    raise SourceNotFetchable, "unsupported scheme: #{uri.scheme}" unless %w[http https].include?(uri.scheme)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
      http.get(uri.request_uri, "User-Agent" => "f-dod/1.0")
    end

    raise SourceNotFetchable, "HTTP #{response.code} fetching #{url}" unless response.is_a?(Net::HTTPSuccess)

    response.body.to_s
  end

  def zip_payload(entry_name, content)
    buffer = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry(entry_name)
      zos.write(content)
    end
    buffer.rewind
    buffer.read
  end

  def filename_for(source)
    basename = File.basename(URI.parse(source.url).path.to_s)
    basename = "source_#{source.id}" if basename.blank? || basename == "/"
    basename.end_with?(".html", ".htm") ? basename : "#{basename}.html"
  end
end
