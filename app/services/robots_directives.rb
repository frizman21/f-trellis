require "nokogiri"

# The page-level half of the robots convention: what a page says about itself,
# through `<meta name="robots">` or the `X-Robots-Tag` response header.
#
# Two directives matter here, and conflating them is the likely mistake:
#
#   nofollow — do not follow the links on this page
#   noindex  — do not keep this page as a retrievable record
#
# `noindex` is the consequential one for this project. A site marking a page
# noindex is saying it does not want that page treated as durable, retrievable
# data — which is close to what turning it into knowledge-graph facts does. A
# noindex page can still be fetched and read by a person; it just does not
# silently become permanent structured data.
class RobotsDirectives
  GENERIC = "robots".freeze

  attr_reader :follow, :index

  def initialize(follow: true, index: true)
    @follow = follow
    @index = index
  end

  def follow? = @follow
  def index? = @index
  def noindex? = !@index
  def nofollow? = !@follow

  def self.permissive
    new
  end

  # Header and meta forms carry the same vocabulary, so both go through here.
  def self.from_content(content)
    tokens = content.to_s.downcase.split(",").map(&:strip)

    return permissive if tokens.empty?

    none = tokens.include?("none")

    new(follow: !(none || tokens.include?("nofollow")),
        index:  !(none || tokens.include?("noindex")))
  end

  # An agent-specific tag outranks the generic one, the same way a robots.txt
  # group naming us outranks `*`.
  def self.from_html(html, agent: CrawlerIdentity.product_token)
    doc = Nokogiri::HTML(html.to_s)
    specific = meta_content(doc, agent.to_s.downcase)

    from_content(specific || meta_content(doc, GENERIC))
  rescue StandardError
    permissive
  end

  def self.meta_content(doc, name)
    doc.css("meta[name]").find { |tag| tag["name"].to_s.strip.downcase == name }&.[]("content")
  end

  # Combines what the page said with what the response header said; the more
  # restrictive of the two wins, since either is the site asking.
  def merge(other)
    return self if other.nil?

    self.class.new(follow: follow && other.follow, index: index && other.index)
  end
end
