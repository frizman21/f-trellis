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

  # Worth asking again: a rate limiter, a deploy, a network blip. Distinct from
  # SourceNotFetchable, which is a definite answer — retrying a 404 is just a
  # second request for the same answer.
  class SourceTemporarilyUnavailable < SourceNotFetchable
    attr_reader :retry_after

    def initialize(message = nil, status_code: nil, retry_after: nil)
      super(message, status_code: status_code)
      @retry_after = retry_after
    end
  end

  # Four attempts over a few minutes covers a deploy window or a brief limiter
  # without turning one bad host into an unbounded queue of retries.
  MAX_ATTEMPTS = 4

  # A server asking us to come back later than this is not worth parking a
  # worker for; the crawl gives up and records why.
  MAX_RETRY_AFTER = 15.minutes

  # Transport failures that never produced a response. Worth one more try for
  # the same reason a 503 is.
  TRANSIENT_ERRORS = [
    Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET,
    Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError
  ].freeze

  # A source left in_work by a worker that died is otherwise unreachable
  # forever: the guard below only lets `new` through. Retries widen that window,
  # so the recovery lands with them.
  STALE_IN_WORK_AFTER = 1.hour

  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 30

  # http -> https, apex -> www and trailing-slash normalization are the ordinary
  # ways a site expresses itself, so a redirect is not an error. Five hops is
  # well past any legitimate chain and short enough that a misconfigured site
  # cannot hold a worker.
  MAX_REDIRECTS = 5

  # Pages, which are parsed as markup and decoded against a declared charset.
  TEXT_CONTENT_TYPES = %w[text/html application/xhtml+xml].freeze

  # Documents, which are stored as the bytes they are and read by their own
  # extractor. #135's guard collapsed two judgments into one — "we cannot parse
  # this as HTML" and "this is not worth reading" — which coincide for an image
  # or a JSON endpoint and do not for a PDF.
  BINARY_CONTENT_TYPES = %w[application/pdf].freeze

  # What this system can actually read. Anything else — an image, a spreadsheet,
  # a JSON document — was reachable but is not something we have a reader for,
  # and storing it means a model is paid to read the noise that falls out.
  ACCEPTED_CONTENT_TYPES = (TEXT_CONTENT_TYPES + BINARY_CONTENT_TYPES).freeze

  # There is no size limit on an HTML fetch, which has been survivable because
  # pages are small. PDFs are not: a 300 MB document would go into a bytea
  # column and through a worker's memory twice over, raw and then zipped.
  #
  # 10 MB sits well above the documents we want — a BAA runs to a few MB at most
  # with figures — and what it excludes is the class we have no use for anyway:
  # scanned-image archives and print-resolution decks, which are image-heavy,
  # which means pdf-reader would extract little from them even if stored.
  #
  # PDF-specific on purpose. Capping HTML would change behaviour no failure has
  # asked us to change, and the distributions genuinely differ: a 10 MB page is
  # pathological and worth looking at, a 10 MB PDF is ordinary and merely
  # useless to us.
  MAX_PDF_BYTES = 10.megabytes

  # What came back, where it came from after any redirects, what the server
  # said it was, the status that ended the attempt, and any X-Robots-Tag it
  # carried. The header is only knowable here — the stored payload is the body
  # alone — which is why it is threaded through rather than re-derived later.
  Fetched = Struct.new(:body, :final_url, :content_type, :status_code, :robots_tag,
                       :etag, :last_modified_at, :not_modified, keyword_init: true) do
    def not_modified? = !!not_modified
  end

  # Only untouched sources are fetched by default, so a crawl revisiting a page
  # does not refetch it. `force: true` is for an explicit request from the UI to
  # grab the content again whatever the current status.
  #
  # Every path through this method leaves a FetchRecord. This is the one place
  # every fetch passes through — a crawl's `perform_now`, the "Fetch content"
  # button, and the fetch a new source queues for itself all arrive here — so
  # logging here is what makes "no fetch without a record" true, rather than
  # three call sites that each have to remember. It is also where the facts
  # are: the status code, the exception and the guard result are all in hand,
  # and none of them have to be reconstructed by a caller.
  def perform(source, force: false, trigger: "manual")
    unless force || source.status == "new" || stale_in_work?(source)
      # No request went out, which is a different fact from one that failed.
      log_fetch(source, nil, "skipped", trigger)
      return
    end

    source.update!(status: "in_work")

    # A forced fetch is an operator asking for the content again. Sending
    # validators would answer that with a 304 and no new payload, which reads
    # as a broken button.
    fetched = fetch_html(source, conditional: !force)

    if fetched.not_modified?
      # The page has not changed, so the datum already held is still current
      # and no second copy is stored.
      source.update!(status: "complete")

      # Still a successful fetch, and still recorded: we asked, and the server
      # answered. The 304 on the record is what distinguishes it from a fetch
      # that stored something, without needing an outcome of its own.
      log_fetch(source, fetched.status_code, "ok", trigger)
      return fetched.status_code
    end

    SourcePayload.store(source: source, content: fetched.body,
                        content_type: fetched.content_type)

    source.update!(status: "complete",
                   resolved_url: resolved_url_for(source, fetched),
                   is_noindex: noindex?(fetched),
                   etag: fetched.etag,
                   last_modified_at: fetched.last_modified_at)

    log_fetch(source, fetched.status_code, "ok", trigger)

    # Still returned for callers that want the status without reading it back
    # off the record.
    fetched.status_code
  rescue SourceNotFetchable => e
    # Rescued ahead of StandardError, which it is. A refused content type
    # answered 200, so the outcome cannot be derived from the status alone.
    source.update!(status: "failed") if source.persisted?
    log_fetch(source, e.status_code, e.status_code.to_i >= 400 ? "http_error" : "unusable", trigger)
    Rails.logger.error("FetchSourceJob failed for source ##{source.id}: #{e.class}: #{e.message}")
    raise
  rescue StandardError => e
    source.update!(status: "failed") if source.persisted?
    log_fetch(source, nil, "no_response", trigger)
    Rails.logger.error("FetchSourceJob failed for source ##{source.id}: #{e.class}: #{e.message}")
    raise
  end

  private

  # The log must never be the reason a fetch fails, so a record that cannot be
  # written is logged and swallowed.
  def log_fetch(source, status_code, outcome, trigger)
    FetchRecord.create!(url: source.url, status_code: status_code, outcome: outcome, trigger: trigger)
  rescue StandardError => e
    Rails.logger.error("FetchSourceJob: could not log #{source.url}: #{e.class}: #{e.message}")
  end

  # Follows redirects to the page that actually answers. Every hop is checked
  # again — scheme, exclusion list, and whether we have already been here — so
  # a redirect cannot walk the crawler somewhere a direct request would refuse
  # to go.
  def fetch_html(source, conditional: false)
    url     = source.url
    current = url
    seen    = Set.new([ url ])

    (MAX_REDIRECTS + 1).times do
      uri = parse_uri(current)
      # Validators describe the original URL, so they are only sent on the first
      # hop — an ETag from A would provoke a spurious 304 from B.
      headers  = conditional && current == url ? conditional_headers(source) : {}
      response = with_retries(current) { request(uri, headers) }

      case classify(response)
      when :success      then return read(response, current)
      when :not_modified then return Fetched.new(final_url: current, not_modified: true,
                                                 status_code: response.code.to_i)
      when :redirect     then current = redirect_target(response, uri, seen)
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
                content_type: type || SourcePayload::DEFAULT_CONTENT_TYPE, status_code: response.code.to_i,
                robots_tag: response["X-Robots-Tag"],
                etag: response["ETag"].presence,
                last_modified_at: parse_http_date(response["Last-Modified"]))
  end

  def decode(response)
    body    = response.body.to_s

    # A server sending `application/pdf; charset=binary` — they exist — would
    # otherwise put force_encoding + encode(invalid: :replace) through the
    # archive bytes and silently corrupt the document. Charset describes text;
    # a PDF is not text.
    return body if BINARY_CONTENT_TYPES.include?(response.content_type.to_s.downcase)

    charset = response.type_params["charset"].presence
    return body if charset.nil?

    body.dup.force_encoding(charset).encode("UTF-8", invalid: :replace, undef: :replace)
  rescue ArgumentError, EncodingError
    # An unknown or lying charset is not worth failing a fetch over; the bytes
    # are still the page.
    body
  end

  # The one place a response's status becomes a decision.
  # 304 is checked before the redirect branch: Net::HTTPNotModified is itself a
  # Net::HTTPRedirection, so the obvious ordering would treat every unchanged
  # page as a redirect with no Location and fail it.
  def classify(response)
    case response
    when Net::HTTPSuccess          then :success
    when Net::HTTPNotModified      then :not_modified
    when Net::HTTPRedirection      then :redirect
    when Net::HTTPTooManyRequests,
         Net::HTTPServerError      then :transient
    else :error
    end
  end

  def conditional_headers(source)
    headers = {}
    headers["If-None-Match"] = source.etag if source.etag.present?
    headers["If-Modified-Since"] = source.last_modified_at.httpdate if source.last_modified_at.present?
    headers
  end

  # Retries live around the request rather than in ActiveJob's retry_on,
  # because CrawlJob calls perform_now — which bypasses the retry machinery
  # entirely. Wiring retry_on alone would fix the "Fetch content" button and
  # leave every crawl exactly as it is today, which is the trap this card is
  # most likely to fall into.
  #
  # The cost of doing it here is that a worker waits during the backoff.
  # MAX_RETRY_AFTER bounds that.
  def with_retries(url)
    attempt = 0

    begin
      attempt += 1
      response = yield

      return response unless classify(response) == :transient

      raise SourceTemporarilyUnavailable.new(
        "HTTP #{response.code} fetching #{url}",
        status_code: response.code.to_i,
        retry_after: retry_after_seconds(response)
      )
    rescue SourceTemporarilyUnavailable, *TRANSIENT_ERRORS => e
      delay = backoff_for(e, attempt)
      raise if attempt >= MAX_ATTEMPTS || delay.nil?

      sleep_for(delay)
      retry
    end
  end

  # A Retry-After the server stated wins over our own backoff — it is an
  # instruction, not a suggestion. nil means "do not wait at all", which ends
  # the retries.
  def backoff_for(error, attempt)
    stated = error.respond_to?(:retry_after) ? error.retry_after : nil

    return stated if stated && stated <= MAX_RETRY_AFTER
    return nil if stated

    2**(attempt - 1)
  end

  # Both forms the header takes: a number of seconds, and an HTTP-date.
  def retry_after_seconds(response)
    raw = response["Retry-After"].to_s.strip
    return nil if raw.empty?
    return raw.to_i if raw.match?(/\A\d+\z/)

    seconds = (Time.httpdate(raw) - Time.current).to_i
    seconds.positive? ? seconds : 0
  rescue ArgumentError
    nil
  end

  def sleep_for(seconds)
    Kernel.sleep(seconds)
  end

  def parse_http_date(value)
    return nil if value.blank?

    Time.httpdate(value)
  rescue ArgumentError
    nil
  end

  # A worker that died mid-fetch leaves a source in_work, and the guard in
  # #perform then means nothing ever picks it up again.
  def stale_in_work?(source)
    source.status == "in_work" && source.updated_at < STALE_IN_WORK_AFTER.ago
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

  # The page's own directives and the response header both count, and the more
  # restrictive wins — either is the site asking.
  def noindex?(fetched)
    # A document has no <meta name="robots">, and handing its bytes to a markup
    # parser would only invite it to find one. The response header still counts:
    # X-Robots-Tag is how a site marks a PDF, and is the only way it can.
    page = if TEXT_CONTENT_TYPES.include?(fetched.content_type)
      RobotsDirectives.from_html(fetched.body)
    else
      RobotsDirectives.permissive
    end

    header = fetched.robots_tag.presence && RobotsDirectives.from_content(fetched.robots_tag)

    page.merge(header).noindex?
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
  # Streamed rather than buffered, so a size limit can be enforced on the way in.
  # `http.get` returns only once the whole body is in memory, which would bound
  # what we *store* while doing nothing about what we *hold* — a server sending
  # 300 MB with no Content-Length would still put 300 MB in the worker.
  #
  # Behaviour-preserving for HTML: same body bytes, same encoding, same
  # exceptions. The response object handed back is a real Net::HTTPResponse with
  # its body already read, exactly as before.
  def request(uri, headers = {})
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                    open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.request_get(uri.request_uri, request_headers.merge(headers)) do |response|
        limit = byte_limit_for(response)

        # The cheap case first: a declared size over the limit is refused before
        # a byte of body is read.
        reject_oversize!(response, declared_length(response), limit)

        body = read_body_within(response, limit)

        # Net::HTTP#reading_body reads the body itself once this block returns,
        # unless it has already been read. Marking it read is what stops a
        # second pass over a socket we have already drained.
        response.instance_variable_set(:@body, body)
        response.instance_variable_set(:@read, true)
        response
      end
    end
  end

  # nil means uncapped. Only the types we know to be large documents are capped;
  # see MAX_PDF_BYTES.
  def byte_limit_for(response)
    BINARY_CONTENT_TYPES.include?(response.content_type.to_s.downcase) ? MAX_PDF_BYTES : nil
  end

  def declared_length(response)
    value = response["Content-Length"]
    value.presence && value.to_i
  end

  # Content-Length is optional and can lie, so the same limit is applied again
  # to what actually arrives.
  def read_body_within(response, limit)
    buffer = +"".b

    response.read_body do |chunk|
      buffer << chunk
      reject_oversize!(response, buffer.bytesize, limit)
    end

    buffer
  end

  def reject_oversize!(response, size, limit)
    return if limit.nil? || size.nil? || size <= limit

    raise SourceNotFetchable.new(
      "response body of #{size} bytes exceeds the #{limit} byte limit",
      status_code: response.code.to_i
    )
  end

  def request_headers
    { "User-Agent" => CrawlerIdentity.user_agent }
  end

end
