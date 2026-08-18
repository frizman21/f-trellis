require "set"

class CrawlJob < ApplicationJob
  queue_as :default

  class NoSitemap < StandardError; end

  CRAWL_TYPES = %w[stay_in_domain follow_external_links from_sitemap].freeze
  DEFAULT_MAX_PAGES = 500
  MAX_MAX_PAGES = 5_000

  # What "the crawler's default" in the domain form means. Ten seconds against a
  # site that never asked us to visit is unambiguously polite — invisible in the
  # target's server load — and the only cost is wall-clock time on a background
  # job nobody is watching. A full 500-page crawl of an untuned domain therefore
  # takes over an hour; an operator who wants it faster sets the domain's minimum
  # crawl delay, which the source page links to alongside the projected time.
  DEFAULT_CRAWL_DELAY_SECONDS = 10

  # An operator's explicit setting wins, then the site's own Crawl-delay, then
  # the default. Stated in one place so the precedence is not rediscovered.
  def self.delay_for(domain)
    domain&.min_crawl_delay_seconds ||
      domain&.robots_crawl_delay_seconds ||
      DEFAULT_CRAWL_DELAY_SECONDS
  end

  def perform(seed_source, crawl_type:, max_depth:, max_pages: DEFAULT_MAX_PAGES, pacer: CrawlPacer.new)
    @pacer = pacer

    crawl_type = crawl_type.to_s
    raise ArgumentError, "invalid crawl_type: #{crawl_type.inspect}" unless CRAWL_TYPES.include?(crawl_type)

    max_depth = max_depth.to_i
    max_pages = [[max_pages.to_i, 1].max, MAX_MAX_PAGES].min

    queue = starting_queue(seed_source, crawl_type, max_pages)
    seen_urls = Set.new(queue.map { |source, _depth| source.url })
    processed = 0

    until queue.empty? || processed >= max_pages
      current, depth = queue.shift
      process_source(current)
      processed += 1

      next if depth >= max_depth

      urls, datum = discovered_links(current, link_mode(crawl_type))

      urls.each do |url|
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
        SourceLink.record(from: current, to: target, datum: datum) if target
      end
    end
  end

  private

  # Every page the crawl processes leaves a FetchRecord, including the ones
  # that failed — but the write lives in FetchSourceJob now, which is the one
  # place every fetch passes through and the place that holds the status code
  # and the exception firsthand. A crawl no longer reconstructs an outcome from
  # a return value; it just fetches and keeps going.
  #
  # The rescue stays, so one page that blows up does not end the crawl.
  def process_source(source)
    # Checked at fetch time rather than at link discovery, so it also covers the
    # seed and any page reached by another route.
    #
    # FetchSourceJob itself is deliberately not gated: the "Fetch content"
    # button is an operator asking for one page, which is a different act from
    # an automated crawl, and gating it would make a disallowed page
    # unfetchable even deliberately.
    if robots_disallow?(source)
      log_disallowed(source)
      return
    end

    # Before the request, not after the last page: a one-page crawl never waits.
    @pacer.wait_for(source.domain&.host, self.class.delay_for(source.domain))

    FetchSourceJob.perform_now(source, trigger: "crawl")
  rescue StandardError => e
    Rails.logger.error("CrawlJob: failed processing #{source.url}: #{e.class}: #{e.message}")
  end

  # Policies are cached per host for the run, so a 500-page crawl of one site
  # asks its robots.txt once.
  def robots_disallow?(source)
    return false if source.domain.nil?

    @policies ||= {}
    policy = (@policies[source.domain.id] ||= RobotsFetcher.policy_for(source.domain))

    policy.disallowed?(RobotsPolicy.path_for(source.url))
  rescue StandardError => e
    # A crawl must not die because robots handling did. Failing open here would
    # be the wrong default, so this fails closed and says why.
    Rails.logger.error("CrawlJob: robots check failed for #{source.url}: #{e.class}: #{e.message}")
    true
  end

  # The one record a crawl still writes itself. Every other outcome is written
  # by FetchSourceJob, but a disallowed page never reaches it — that is the
  # point of the check — so there is nothing downstream to do the logging.
  #
  # The log must not be the reason a crawl stops, so a record that cannot be
  # written is logged and swallowed like any other per-page failure.
  def log_disallowed(source)
    FetchRecord.create!(url: source.url, status_code: nil, outcome: "disallowed", trigger: "crawl")
  rescue StandardError => e
    Rails.logger.error("CrawlJob: could not log #{source.url}: #{e.class}: #{e.message}")
  end

  # A sitemap crawl seeds the queue with everything the site listed and then
  # runs the ordinary loop, so max_pages, exclusions, robots, pacing, parentage
  # and the link graph all behave exactly as they do on any other crawl. A
  # second traversal would have to reimplement all of it.
  def starting_queue(seed_source, crawl_type, max_pages)
    return [ [ seed_source, 0 ] ] unless crawl_type == "from_sitemap"

    sources = sitemap_sources(seed_source, max_pages)
    raise NoSitemap, "no sitemap found for #{seed_source.domain&.host}" if sources.empty?

    sources.map { |source| [ source, 0 ] }
  end

  def sitemap_sources(seed_source, max_pages)
    host = seed_source.domain&.host
    entries = SitemapReader.locations_for(seed_source.domain)
                           .flat_map { |location| SitemapReader.call(location).entries }

    # A sitemap naming another host is either a mistake or an attempt to send
    # our crawl elsewhere; neither is worth following implicitly.
    entries = entries.select { |entry| same_host?(entry.url, host) }
    entries = entries.uniq(&:url).first(max_pages)

    exclusions = SourceExclusion.enabled.to_a
    entries.reject! { |entry| exclusions.any? { |rule| rule.matches?(entry.url) } }

    Rails.logger.info("CrawlJob: sitemap for #{host} offered #{entries.size} usable urls")

    entries.filter_map { |entry| source_for_sitemap_entry(entry, seed_source) }
  end

  def source_for_sitemap_entry(entry, seed_source)
    source = Source.find_by(url: entry.url) ||
             Source.create!(url: entry.url,
                            parent_source: seed_source,
                            description: "Listed in the sitemap for #{seed_source.domain&.host}")

    source.update_columns(sitemap_lastmod_at: entry.lastmod) if entry.lastmod
    source
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("CrawlJob: skipping sitemap url #{entry.url}: #{e.message}")
    nil
  end

  def same_host?(url, host)
    URI.parse(url).host&.downcase == host&.downcase
  rescue URI::InvalidURIError
    false
  end

  # Links found on sitemap-seeded pages are followed within the domain, the
  # same as a stay-in-domain crawl.
  def link_mode(crawl_type)
    crawl_type == "from_sitemap" ? "stay_in_domain" : crawl_type
  end

  # Returns the links *and* the snapshot they came out of, so the edge write can
  # name it. Looking the datum up a second time at the write would risk a
  # different answer if a fetch landed in between.
  def discovered_links(source, crawl_type)
    datum = source.source_data.order(:created_at).last
    return [ [], nil ] unless datum

    result = datum.extract_links

    urls =
      case crawl_type
      when "stay_in_domain"        then result.internal
      when "follow_external_links" then result.internal + result.external
      end

    [ urls, datum ]
  end
end
