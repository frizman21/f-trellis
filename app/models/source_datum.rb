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

  # Payloads whose bytes are a document rather than markup. Named as an
  # allowlist of the binary types rather than of the textual ones on purpose:
  # rows predating content_type carry the container's own "application/zip" and
  # a handful carry nothing, and neither should stop behaving like a page.
  BINARY_CONTENT_TYPES = %w[application/pdf].freeze

  PDF_CONTENT_TYPE = "application/pdf".freeze

  # nil for a document. Returning nil rather than raising keeps LearningSet and
  # the source page working on a mixed set without either growing a type check,
  # and the force_encoding below must never be the path a PDF takes — it would
  # corrupt the bytes before any parser saw them.
  def html
    return nil if binary?

    bytes = raw_bytes
    return nil if bytes.nil?

    # +str because an empty entry reads back as a frozen string, and
    # force_encoding mutates in place.
    (+bytes).force_encoding("UTF-8")
  end

  # The visible text of whatever was stored, with markup or page structure
  # stripped. This is what gets sent to a model; #html stays available for link
  # extraction, which needs the anchors.
  #
  # The one dispatch point in the system: every reader already goes through here
  # — ProcessReportJob, SkillTriage, Source#latest_text, LearningSet — so none of
  # them has to learn what a PDF is.
  def text
    if content_type == PDF_CONTENT_TYPE
      PdfExtractor.call(raw_bytes)
    else
      ContentExtractor.call(html)
    end
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
    return LinkExtractor::Result.new(internal: [], external: [], excluded: [], nofollowed: []) if content.blank?

    exclude(LinkExtractor.call(content, base_url: source.url))
  end

  def binary?
    BINARY_CONTENT_TYPES.include?(content_type)
  end

  # The stored payload, unzipped, with no encoding applied — what the download
  # path hands back and what a document's parser reads. #html is the only caller
  # that should tag these bytes as UTF-8; a PDF's must arrive exactly as stored.
  def raw_bytes
    return nil if data.blank?

    Zip::InputStream.open(StringIO.new(data)) do |io|
      entry = io.get_next_entry
      return nil unless entry

      io.read.to_s
    end
  end

  private

  def exclude(result)
    patterns = SourceExclusion.enabled.to_a
    return result if patterns.empty?

    internal, excluded_internal = SourceExclusion.partition_urls(result.internal, patterns)
    external, excluded_external = SourceExclusion.partition_urls(result.external, patterns)

    LinkExtractor::Result.new(internal: internal, external: external,
                              excluded: excluded_internal + excluded_external,
                              nofollowed: result.nofollowed)
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
