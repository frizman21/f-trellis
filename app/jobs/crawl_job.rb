require "set"

class CrawlJob < ApplicationJob
  queue_as :default

  CRAWL_TYPES = %w[stay_in_domain follow_external_links].freeze
  DEFAULT_MAX_PAGES = 500
  MAX_MAX_PAGES = 5_000

  def perform(seed_source, crawl_type:, max_depth:, max_pages: DEFAULT_MAX_PAGES)
    crawl_type = crawl_type.to_s
    raise ArgumentError, "invalid crawl_type: #{crawl_type.inspect}" unless CRAWL_TYPES.include?(crawl_type)

    max_depth = max_depth.to_i
    max_pages = [[max_pages.to_i, 1].max, MAX_MAX_PAGES].min

    queue = [[seed_source, 0]]
    seen_urls = Set.new([seed_source.url])
    processed = 0

    until queue.empty? || processed >= max_pages
      current, depth = queue.shift
      process_source(current)
      processed += 1

      next if depth >= max_depth

      discovered_links(current, crawl_type).each do |url|
        break if processed + queue.size >= max_pages
        next if seen_urls.include?(url)

        seen_urls << url
        next if Source.exists?(url: url)

        child = Source.create!(url: url, description: "Discovered by crawl from #{seed_source.url}")
        queue << [child, depth + 1]
      end
    end
  end

  private

  def process_source(source)
    FetchSourceJob.perform_now(source)
    CrawlRecord.create!(url: source.url)
  rescue StandardError => e
    Rails.logger.error("CrawlJob: failed processing #{source.url}: #{e.class}: #{e.message}")
  end

  def discovered_links(source, crawl_type)
    datum = source.source_data.order(:created_at).last
    return [] unless datum

    html = datum.html
    return [] if html.blank?

    result = LinkExtractor.call(html, base_url: source.url)
    case crawl_type
    when "stay_in_domain"      then result.internal
    when "follow_external_links" then result.internal + result.external
    end
  end
end
