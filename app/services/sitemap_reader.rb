require "net/http"
require "nokogiri"
require "zlib"
require "stringio"

# Reads a site's own list of its pages.
#
# Link-following inherits every weakness of a site's internal linking: pages
# reachable only through a search form, a paginated archive, or a nav the
# crawler cannot see are invisible to it, and reaching a page four clicks deep
# costs four fetches. A sitemap is the site stating its pages directly.
class SitemapReader
  Entry = Struct.new(:url, :lastmod, keyword_init: true)

  # A sitemap index can name sitemaps that name sitemaps. One level down is
  # enough for every real site and bounds a broken or hostile one.
  MAX_INDEX_DEPTH = 1

  # One enormous sitemap must not exhaust memory.
  MAX_ENTRIES = 10_000

  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15

  Result = Struct.new(:entries, :error, keyword_init: true) do
    def entries = self[:entries] || []
    def success? = error.nil?
    # An empty sitemap is an answer, not a failure.
    def any? = entries.any?
  end

  class << self
    # Where a site declares its sitemaps, in order: robots.txt first, because
    # that is where a site says so and they may not live at the conventional
    # path; then the conventional path.
    def locations_for(domain)
      declared = RobotsFetcher.policy_for(domain).sitemaps
      return declared if declared.any?

      [ "https://#{domain.host}/sitemap.xml" ]
    end

    def call(url, depth: 0)
      body = fetch(url)
      return Result.new(entries: [], error: "could not read #{url}") if body.nil?

      parse(body, depth: depth)
    rescue StandardError => e
      Result.new(entries: [], error: "#{e.class}: #{e.message}")
    end

    def parse(body, depth: 0)
      doc = Nokogiri::XML(body)
      return Result.new(entries: [], error: "not valid XML") if doc.errors.any? && doc.root.nil?

      if doc.root&.name == "sitemapindex"
        return Result.new(entries: [], error: "sitemap index nested too deeply") if depth >= MAX_INDEX_DEPTH

        return follow_index(doc, depth)
      end

      Result.new(entries: entries_from(doc))
    end

    private

    def follow_index(doc, depth)
      children = doc.css("sitemap > loc").map { |loc| loc.text.strip }.reject(&:empty?)
      entries = children.flat_map { |child| call(child, depth: depth + 1).entries }

      Result.new(entries: entries.first(MAX_ENTRIES))
    end

    def entries_from(doc)
      doc.css("url").filter_map do |node|
        loc = node.at_css("loc")&.text.to_s.strip
        next if loc.empty?

        Entry.new(url: loc, lastmod: parse_time(node.at_css("lastmod")&.text))
      end.first(MAX_ENTRIES)
    end

    def parse_time(value)
      return nil if value.blank?

      Time.zone.parse(value.strip)
    rescue ArgumentError
      nil
    end

    def fetch(url)
      uri = URI.parse(url.to_s)
      return nil unless %w[http https].include?(uri.scheme)

      response = request(uri)
      return nil unless response.is_a?(Net::HTTPSuccess)

      decompress(url, response.body.to_s)
    rescue URI::InvalidURIError
      nil
    end

    def decompress(url, body)
      return body unless url.to_s.end_with?(".gz") || body.start_with?("\x1F\x8B".b)

      Zlib::GzipReader.new(StringIO.new(body)).read
    rescue Zlib::Error
      body
    end

    def request(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                      open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.get(uri.request_uri, "User-Agent" => CrawlerIdentity.user_agent)
      end
    end
  end
end
