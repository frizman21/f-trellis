# What the crawler tells a server it is.
#
# The name is "f-agents", not "f-dod", and that mismatch is deliberate. This
# application is f-dod; f-agents is the project the crawler belongs to, and it
# is the token a site operator sees in their logs, looks up, and writes a
# robots.txt rule against. A stable public identity that outlives any single
# application is worth more than one that matches the local repository name.
# Do not rename it to match the app.
#
# The contact URL is the other half of being accountable: an operator who finds
# our traffic has somewhere to go to learn what the crawler does and how to ask
# it to stop. It defaults to a real, already-public address rather than a path
# on whatever host this is deployed to, because it has to resolve from the
# outside, from any environment, without depending on this app being reachable.
#
# Note what this is not: an attempt to look like a browser. Sending a fake
# Chrome user-agent would make robots.txt compliance unverifiable from the
# server side and the traffic unattributable, which defeats the point.
class CrawlerIdentity
  DEFAULT_NAME = "f-agents".freeze
  DEFAULT_CONTACT_URL = "https://github.com/f-agents".freeze

  # Anything that would let a configured value break out of the header it is
  # written into. This value is operator-supplied and goes straight into a
  # request header, so it is stripped rather than trusted.
  UNSAFE = /[[:cntrl:]]/

  class << self
    def user_agent
      [ agent, contact_suffix ].compact.join(" ")
    end

    # Just the product token, with no version and no contact URL — the form a
    # robots.txt group names, and the form a `<meta name="...">` directive uses.
    # A site writing `User-agent: f-agents` must match us.
    def product_token
      agent.split("/").first.to_s.split(" ").first.to_s
    end

    private

    def agent
      sanitize(configured_user_agent).presence || default_agent
    end

    def default_agent
      version = AppVersion.short
      version.present? ? "#{DEFAULT_NAME}/#{version}" : DEFAULT_NAME
    end

    # Omitted when the agent already carries a contact URL, so an operator who
    # sets a complete string by hand does not get a second one appended.
    def contact_suffix
      return nil if agent.include?("(+")

      url = contact_url
      url.present? ? "(+#{url})" : nil
    end

    # A contact URL set to an empty string is an explicit "no contact URL" and
    # is honoured; one that is absent entirely falls back to the default.
    def contact_url
      if ENV.key?("CRAWLER_CONTACT_URL")
        sanitize(ENV["CRAWLER_CONTACT_URL"]).presence
      else
        sanitize(credential(:crawler_contact_url)).presence || DEFAULT_CONTACT_URL
      end
    end

    def configured_user_agent
      ENV.fetch("CRAWLER_USER_AGENT") { credential(:crawler_user_agent) }
    end

    def credential(key)
      Rails.application.credentials.dig(key)
    end

    def sanitize(value)
      value.to_s.gsub(UNSAFE, "").strip
    end
  end
end
