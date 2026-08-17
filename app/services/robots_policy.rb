# A parsed robots.txt, answering what a site permits.
#
# Follows RFC 9309: one group applies, chosen by the most specific matching
# user-agent; Allow and Disallow are matched by longest pattern, with Allow
# winning a tie; an empty Disallow means allow everything; `*` and `$` are the
# only wildcards.
#
# This is a voluntary convention, not an access control. Honouring it is a
# decision about how this project behaves, and holding the decision in one
# readable place is the point of parsing the file rather than ignoring it.
class RobotsPolicy
  Rule = Struct.new(:allow, :pattern, :regexp, :length)

  attr_reader :crawl_delay, :sitemaps

  def initialize(rules: [], crawl_delay: nil, sitemaps: [], allow_everything: false, deny_everything: false)
    @rules = rules
    @crawl_delay = crawl_delay
    @sitemaps = sitemaps
    @allow_everything = allow_everything
    @deny_everything = deny_everything
  end

  # A site that has no robots.txt has not asked for anything.
  def self.allow_all
    new(allow_everything: true)
  end

  # RFC 9309: a robots.txt we could not read means the site is off limits until
  # we can. The conservative branch, and the one most likely to surprise — a
  # host with a flaky robots endpoint becomes uncrawlable.
  def self.deny_all
    new(deny_everything: true)
  end

  def self.parse(body, agent:)
    groups = []
    current = nil
    sitemaps = []

    body.to_s.each_line do |raw|
      line = raw.split("#", 2).first.to_s.strip
      next if line.empty?

      field, value = line.split(":", 2)
      next if value.nil?

      field = field.strip.downcase
      value = value.strip

      case field
      when "sitemap"
        sitemaps << value if value.present?
      when "user-agent"
        # Consecutive user-agent lines share one group; a rule line closes the
        # agent list, so the next user-agent starts a new group.
        current = nil if current&.fetch(:closed)
        current ||= begin
          group = { agents: [], rules: [], crawl_delay: nil, closed: false }
          groups << group
          group
        end
        current[:agents] << value.downcase
      when "allow", "disallow"
        next if current.nil?

        current[:closed] = true
        # An empty Disallow means "nothing is disallowed", so it contributes no
        # rule at all rather than a rule matching everything.
        current[:rules] << build_rule(field == "allow", value) if value.present?
      when "crawl-delay"
        next if current.nil?

        current[:closed] = true
        current[:crawl_delay] = value.to_f.ceil if value.to_f.positive?
      end
    end

    group = select_group(groups, agent.to_s.downcase)
    return new(sitemaps: sitemaps, allow_everything: true) if group.nil?

    new(rules: group[:rules], crawl_delay: group[:crawl_delay], sitemaps: sitemaps)
  end

  # Exactly one group applies: ours if the file names us, otherwise the
  # wildcard. A file that names us and also has a `*` group means the `*` group
  # is not for us and must be ignored entirely.
  def self.select_group(groups, agent)
    groups.find { |group| group[:agents].include?(agent) } ||
      groups.find { |group| group[:agents].include?("*") }
  end

  def self.build_rule(allow, pattern)
    Rule.new(allow, pattern, compile(pattern), pattern.length)
  end

  # `*` is any run of characters and `$` anchors the end; everything else is
  # literal. Matched from the start of the path, which is what makes
  # `Disallow: /private` cover `/private/page`.
  def self.compile(pattern)
    body = pattern.split("*", -1).map { |literal| Regexp.escape(literal) }.join(".*")
    body = "#{body.delete_suffix('\\$')}\\z" if pattern.end_with?("$")

    Regexp.new("\\A#{body}")
  end

  def allowed?(path)
    return true if @allow_everything
    return false if @deny_everything

    best = best_rule(normalize(path))
    best.nil? || best.allow
  end

  def disallowed?(path)
    !allowed?(path)
  end

  # The path and query a URL presents to a server, which is what robots.txt
  # patterns are written against.
  def self.path_for(url)
    uri = URI.parse(url.to_s)
    path = uri.path.presence || "/"
    uri.query.present? ? "#{path}?#{uri.query}" : path
  rescue URI::InvalidURIError
    "/"
  end

  private

  def normalize(path)
    candidate = path.to_s
    candidate.start_with?("/") ? candidate : "/#{candidate}"
  end

  # Longest pattern wins; Allow wins a tie. Both are RFC 9309.
  def best_rule(path)
    best = nil

    @rules.each do |rule|
      next unless rule.regexp.match?(path)

      if best.nil? ||
         rule.length > best.length ||
         (rule.length == best.length && rule.allow && !best.allow)
        best = rule
      end
    end

    best
  end
end
