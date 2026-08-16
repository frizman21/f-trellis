require "zip"
require "stringio"
require "digest"

class SourceDatum < ApplicationRecord
  belongs_to :source
  # Edges found in this snapshot. Nullified rather than destroyed: deleting an
  # old copy of a page must not delete links that are still true. The edge
  # outlives the evidence.
  has_many :source_links, dependent: :nullify

  before_save :assign_content_hash

  def html
    return nil if data.blank?

    Zip::InputStream.open(StringIO.new(data)) do |io|
      entry = io.get_next_entry
      return nil unless entry
      # +str because an empty entry reads back as a frozen string, and
      # force_encoding mutates in place.
      (+io.read.to_s).force_encoding("UTF-8")
    end
  end

  # The page's visible text, with markup stripped. This is what gets sent to a
  # model; #html stays available for link extraction, which needs the anchors.
  def text
    ContentExtractor.call(html)
  end

  # Unzip the stored payload and pull the links out of it. Shared by CrawlJob,
  # which uses the result to decide which pages to visit next.
  #
  # The SourceExclusion list is applied here rather than in either caller, so
  # there is one place a link can be dropped and no way to reach the raw list
  # by forgetting to filter. Excluded URLs are reported back rather than
  # silently dropped — see the "Extract links" page.
  def extract_links
    content = html
    return LinkExtractor::Result.new(internal: [], external: [], excluded: []) if content.blank?

    exclude(LinkExtractor.call(content, base_url: source.url))
  end

  private

  def exclude(result)
    patterns = SourceExclusion.enabled.to_a
    return result if patterns.empty?

    internal, excluded_internal = SourceExclusion.partition_urls(result.internal, patterns)
    external, excluded_external = SourceExclusion.partition_urls(result.external, patterns)

    LinkExtractor::Result.new(internal: internal, external: external,
                              excluded: excluded_internal + excluded_external)
  end

  def assign_content_hash
    return unless data_changed? || content_hash.nil?

    self.content_hash = computed_content_hash
  end

  # Hashed over the *extracted text*, not the stored bytes: two fetches of a page
  # whose markup, ad slots or session ids shifted but whose content did not
  # should collapse to the same hash and not earn a second processing run.
  def computed_content_hash
    content = text
    return nil if content.blank?

    Digest::SHA256.hexdigest(content)
  end
end
