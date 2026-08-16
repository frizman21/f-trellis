require "net/http"
require "zip"

class FetchSourceJob < ApplicationJob
  queue_as :default

  # The status code travels on the exception rather than only inside its
  # message. The message is human-facing prose that any later change may
  # reword; a regex over it would fail silently rather than loudly.
  class SourceNotFetchable < StandardError
    attr_reader :status_code

    def initialize(message = nil, status_code: nil)
      super(message)
      @status_code = status_code
    end
  end

  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 30

  # http -> https, apex -> www and trailing-slash normalization are the ordinary
  # ways a site expresses itself, so a redirect is not an error. Five hops is
  # well past any legitimate chain and short enough that a misconfigured site
  # cannot hold a worker.
  MAX_REDIRECTS = 5

  # What this system can actually read. Anything else — a PDF, an image, a JSON
  # document — was reachable but is not a web page, and storing it as one means
  # Nokogiri parses the binary and a model is paid to read the noise that falls
  # out of it.
  ACCEPTED_CONTENT_TYPES = %w[text/html application/xhtml+xml].freeze

  # Assumed when a server sends no Content-Type at all. Some do; refusing them
  # would be stricter than the situation warrants, and the parse path already
  # tolerates whatever it gets.
  DEFAULT_CONTENT_TYPE = "text/html".freeze

  # What came back, where it came from after any redirects, what the server
  # said it was, and the status that ended the attempt.
  Fetched = Struct.new(:body, :final_url, :content_type, :status_code, keyword_init: true)

  # Only untouched sources are fetched by default, so a crawl revisiting a page
  # does not refetch it. `force: true` is for an explicit request from the UI to
  # grab the content again whatever the current status.
  def perform(source, force: false)
    return unless force || source.status == "new"

    source.update!(status: "in_work")

    fetched = fetch_html(source.url)
    bytes   = zip_payload(filename_for(source), fetched.body)

    SourceDatum.create!(
      source: source,
      content_type: fetched.content_type,
      data: bytes
    )

    source.update!(status: "complete", resolved_url: resolved_url_for(source, fetched))

    # Returned so the crawl can log what the server actually answered. nil from
    # the guard above means no request was made at all, which is a different
    # fact and is recorded as such.
    fetched.status_code
  rescue StandardError => e
    source.update!(status: "failed") if source.persisted?
    Rails.logger.error("FetchSourceJob failed for source ##{source.id}: #{e.class}: #{e.message}")
    raise
  end

  private

  # Follows redirects to the page that actually answers. Every hop is checked
  # again — scheme, exclusion list, and whether we have already been here — so
  # a redirect cannot walk the crawler somewhere a direct request would refuse
  # to go.
  def fetch_html(url)
    current = url
    seen    = Set.new([ url ])

    (MAX_REDIRECTS + 1).times do
      uri      = parse_uri(current)
      response = request(uri)

      case classify(response)
      when :success  then return read(response, current)
      when :redirect then current = redirect_target(response, uri, seen)
      else raise SourceNotFetchable.new("HTTP #{response.code} fetching #{current}",
                                        status_code: response.code.to_i)
      end
    end

    raise SourceNotFetchable, "too many redirects from #{url}"
  end

  # Checks what the server actually sent before it is stored as a web page, and
  # decodes it while the declared charset is still in hand. By the time
  # SourceDatum#html reads the bytes back the charset is long gone, which is why
  # its force_encoding raises on invalid sequences far from the cause.
  def read(response, url)
    type = response.content_type.to_s.downcase.presence

    if type && ACCEPTED_CONTENT_TYPES.exclude?(type)
      # The status travels even though the request succeeded: the server
      # answered fine, we are the ones refusing what it sent.
      raise SourceNotFetchable.new("unsupported content type: #{type} at #{url}",
                                   status_code: response.code.to_i)
    end

    Fetched.new(body: decode(response), final_url: url,
                content_type: type || DEFAULT_CONTENT_TYPE, status_code: response.code.to_i)
  end

  def decode(response)
    body    = response.body.to_s
    charset = response.type_params["charset"].presence
    return body if charset.nil?

    body.dup.force_encoding(charset).encode("UTF-8", invalid: :replace, undef: :replace)
  rescue ArgumentError, EncodingError
    # An unknown or lying charset is not worth failing a fetch over; the bytes
    # are still the page.
    body
  end

  # The one place a response's status becomes a decision. Later work — treating
  # 429 and 5xx as transient, admitting 304 as a success — extends this rather
  # than adding another branch to the caller.
  def classify(response)
    case response
    when Net::HTTPSuccess     then :success
    when Net::HTTPRedirection then :redirect
    else :error
    end
  end

  def redirect_target(response, uri, seen)
    location = response["Location"].presence
    raise SourceNotFetchable, "redirect with no Location from #{uri}" if location.nil?

    target = URI.join(uri, location).to_s
    raise SourceNotFetchable, "redirect loop at #{target}" if seen.include?(target)
    raise SourceNotFetchable, "redirect to an excluded URL: #{target}" if excluded?(target)

    seen << target
    target
  rescue URI::InvalidURIError, ArgumentError
    raise SourceNotFetchable, "unusable redirect target #{location.inspect} from #{uri}"
  end

  # A hop must not bypass the exclusion list. The list is otherwise only
  # consulted during link extraction, which a redirect never passes through.
  def excluded?(url)
    SourceExclusion.enabled.any? { |exclusion| exclusion.matches?(url) }
  end

  # Recorded only when it differs, so the column answers "was this moved?"
  # rather than repeating `url` on every row.
  def resolved_url_for(source, fetched)
    fetched.final_url == source.url ? nil : fetched.final_url
  end

  def parse_uri(url)
    uri = URI.parse(url)
    raise SourceNotFetchable, "unsupported scheme: #{uri.scheme}" unless %w[http https].include?(uri.scheme)

    uri
  end

  # The single outbound request, kept on its own so a test can stub one HTTP
  # call without stubbing the logic wrapped around it. Stubbing #fetch_html
  # instead — as the tests did before this seam existed — makes headers, status
  # codes, redirects and content types all unobservable.
  def request(uri, headers = {})
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                    open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.get(uri.request_uri, request_headers.merge(headers))
    end
  end

  def request_headers
    { "User-Agent" => CrawlerIdentity.user_agent }
  end

  def zip_payload(entry_name, content)
    buffer = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry(entry_name)
      zos.write(content)
    end
    buffer.rewind
    buffer.read
  end

  def filename_for(source)
    basename = File.basename(URI.parse(source.url).path.to_s)
    basename = "source_#{source.id}" if basename.blank? || basename == "/"
    basename.end_with?(".html", ".htm") ? basename : "#{basename}.html"
  end
end
