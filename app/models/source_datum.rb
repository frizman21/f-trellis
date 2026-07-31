require "zip"
require "stringio"

class SourceDatum < ApplicationRecord
  belongs_to :source

  def html
    return nil if data.blank?

    Zip::InputStream.open(StringIO.new(data)) do |io|
      entry = io.get_next_entry
      return nil unless entry
      io.read
    end
  end

  # Unzip the stored payload and pull the links out of it. Shared by CrawlJob,
  # which uses the result to decide which pages to visit next.
  def extract_links
    content = html
    return LinkExtractor::Result.new(internal: [], external: []) if content.blank?

    LinkExtractor.call(content, base_url: source.url)
  end
end
