require "net/http"

# Fetches and caches a site's robots.txt, and hands back the policy it states.
#
# Cached on the Domain and re-read once a day. A crawl asks for the policy once
# per host, not once per page.
class RobotsFetcher
  STALE_AFTER = 24.hours
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  # Status handling per RFC 9309. The 5xx branch is the one worth knowing about:
  # a robots.txt we could not read means the site is off limits until we can.
  STATUS_OK          = "ok".freeze          # parsed and stored
  STATUS_ABSENT      = "absent".freeze      # 404/410 — nothing was asked of us
  STATUS_UNREACHABLE = "unreachable".freeze # 5xx or a timeout — assume disallowed

  class << self
    def policy_for(domain, agent: CrawlerIdentity.product_token)
      return RobotsPolicy.allow_all if domain.nil?

      refresh(domain) if stale?(domain)

      case domain.robots_status
      when STATUS_OK          then RobotsPolicy.parse(domain.robots_txt, agent: agent)
      when STATUS_UNREACHABLE then RobotsPolicy.deny_all
      else RobotsPolicy.allow_all
      end
    end

    def stale?(domain)
      domain.robots_fetched_at.nil? || domain.robots_fetched_at < STALE_AFTER.ago
    end

    def refresh(domain)
      response = request(URI.parse("https://#{domain.host}/robots.txt"))

      case response
      when Net::HTTPSuccess then store(domain, STATUS_OK, response.body.to_s)
      when Net::HTTPNotFound, Net::HTTPGone then store(domain, STATUS_ABSENT, nil)
      else store(domain, STATUS_UNREACHABLE, nil)
      end
    rescue StandardError => e
      Rails.logger.warn("RobotsFetcher: could not read robots.txt for #{domain.host}: #{e.class}: #{e.message}")
      store(domain, STATUS_UNREACHABLE, nil)
    end

    private

    def store(domain, status, body)
      delay = status == STATUS_OK ? RobotsPolicy.parse(body, agent: CrawlerIdentity.product_token).crawl_delay : nil

      domain.update_columns(
        robots_txt: body,
        robots_status: status,
        robots_fetched_at: Time.current,
        robots_crawl_delay_seconds: delay
      )
      domain.reload
    end

    # The same single-request seam FetchSourceJob uses, for the same reason.
    def request(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                      open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.get(uri.request_uri, "User-Agent" => CrawlerIdentity.user_agent)
      end
    end
  end
end
