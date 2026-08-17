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
        target = Source.find_by(url: url)

        # Only URLs we have not seen and have no source for get created and
        # queued; the max_pages cap bounds queueing, not link recording.
        if target.nil? && !seen_urls.include?(url) && processed + queue.size < max_pages
          # Parent is the page the link was actually found on, which is only
          # the seed at depth 1.
          target = Source.create!(url: url,
                                  parent_source: current,
                                  description: "Discovered by crawl from #{seed_source.url}")
          queue << [target, depth + 1]
        end

        seen_urls << url

        # Record the edge either way, so links back to pages we already know
        # about still show up in the graph.
        SourceLink.record(from: current, to: target) if target
      end
    end
  end

  private

  # Every page the crawl processes leaves a record, including the ones that
  # failed. Previously the write sat after the fetch inside this rescue, so a
  # failed page left nothing behind while still consuming the page budget —
  # a crawl where everything failed produced an empty log, indistinguishable
  # from a crawl that never ran.
  #
  # One record per page, carrying the outcome that ended the attempt. A page
  # that redirected twice before answering logs the final status, because the
  # unit of this log is a page processed, matching `processed` and `max_pages`.
  def process_source(source)
    status_code = FetchSourceJob.perform_now(source)

    # nil without an exception means the fetch guard declined: the page was
    # already held, so no request went out.
    log_crawl(source, status_code, status_code.nil? ? "skipped" : "ok")
  rescue FetchSourceJob::SourceNotFetchable => e
    log_crawl(source, e.status_code, e.status_code.to_i >= 400 ? "http_error" : "unusable")
    Rails.logger.error("CrawlJob: failed processing #{source.url}: #{e.class}: #{e.message}")
  rescue StandardError => e
    log_crawl(source, nil, "no_response")
    Rails.logger.error("CrawlJob: failed processing #{source.url}: #{e.class}: #{e.message}")
  end

  # The log must not be the reason a crawl stops, so a record that cannot be
  # written is logged and swallowed like any other per-page failure.
  def log_crawl(source, status_code, outcome)
    CrawlRecord.create!(url: source.url, status_code: status_code, outcome: outcome)
  rescue StandardError => e
    Rails.logger.error("CrawlJob: could not log #{source.url}: #{e.class}: #{e.message}")
  end

  def discovered_links(source, crawl_type)
    datum = source.source_data.order(:created_at).last
    return [] unless datum

    result = datum.extract_links
    case crawl_type
    when "stay_in_domain"      then result.internal
    when "follow_external_links" then result.internal + result.external
    end
  end
end
