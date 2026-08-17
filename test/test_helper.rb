ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Stubs the crawler's single outbound HTTP request.
#
# The seam is FetchSourceJob#request, one Net::HTTP call with nothing else in
# it. Stubbing there rather than at #fetch_html — which is what these tests did
# before the seam existed — is what keeps headers, status codes, redirects and
# content types observable; stubbing the whole of #fetch_html hides all four.
#
# There is no WebMock or VCR in the Gemfile, so this stays the hand-rolled
# alias_method pattern the suite already used.
module FakeHttp
  # Yields a list that fills with { uri:, headers: } for each request made, so
  # a test can assert on what went out as well as what came back.
  #
  # `responses` may be a single response spec or an array of them, taken in
  # order — a redirect chain is several, a plain fetch is one.
  def with_fake_http(body = "<html><body>hi</body></html>", code: "200", headers: {}, responses: nil, &block)
    specs = responses || [ { code: code, body: body, headers: headers } ]
    queue = Array(specs).dup
    requests = []

    slept = []

    FetchSourceJob.class_eval do
      alias_method :request_without_stub, :request
      define_method(:request) do |uri, extra = {}|
        requests << { uri: uri, headers: request_headers.merge(extra) }
        spec = queue.size > 1 ? queue.shift : queue.first
        raise spec[:raise] if spec[:raise]

        FakeHttp.build_response(spec)
      end

      # Backoff must not actually wait, or the suite grows by minutes and stops
      # being run. Recorded so the wait itself stays assertable.
      alias_method :sleep_for_without_stub, :sleep_for
      define_method(:sleep_for) { |seconds| slept << seconds }
    end

    @fake_http_slept = slept
    block.arity.zero? ? yield : yield(requests)
  ensure
    FetchSourceJob.class_eval do
      remove_method :request
      alias_method :request, :request_without_stub
      remove_method :request_without_stub

      remove_method :sleep_for
      alias_method :sleep_for, :sleep_for_without_stub
      remove_method :sleep_for_without_stub
    end
  end

  # What the retry backoff would have waited, in order.
  def fake_http_slept
    @fake_http_slept || []
  end

  # Stubs one level lower than with_fake_http — at Net::HTTP itself — so
  # FetchSourceJob#request runs for real.
  #
  # Everything about the streamed read is only observable through this seam: the
  # Content-Length pre-check, the running size cap, and whether the body is
  # assembled from chunks byte-identically. with_fake_http replaces #request
  # outright and would hide all of it.
  #
  # Yields a Transfer recording what the read actually did, so "it stopped
  # early" is assertable rather than assumed.
  def with_streaming_http(chunks:, code: "200", headers: {}, on_read: nil)
    transfer = FakeHttp::Transfer.new(chunks: chunks, on_read: on_read)
    response = FakeHttp.build_streaming_response(code: code, headers: headers, transfer: transfer)
    http     = FakeHttp::Connection.new(response, transfer)

    Net::HTTP.singleton_class.class_eval do
      alias_method :start_without_stub, :start
      define_method(:start) { |*, **, &blk| blk.call(http) }
    end

    yield transfer
  ensure
    Net::HTTP.singleton_class.class_eval do
      remove_method :start
      alias_method :start, :start_without_stub
      remove_method :start_without_stub
    end
  end

  # Records what a streamed read did, so a test can tell "refused after reading
  # nothing" from "refused after buffering the lot".
  class Transfer
    attr_reader :delivered, :request_path, :request_headers

    def initialize(chunks:, on_read: nil)
      @chunks    = chunks
      @on_read   = on_read
      @delivered = 0
    end

    def each_chunk
      @on_read&.call

      @chunks.each do |chunk|
        @delivered += chunk.bytesize
        yield chunk
      end
    end

    def record_request(path, headers)
      @request_path    = path
      @request_headers = headers
    end
  end

  class Connection
    def initialize(response, transfer)
      @response = response
      @transfer = transfer
    end

    def request_get(path, headers = {}, &block)
      @transfer.record_request(path, headers)
      block.call(@response)
    end
  end

  # A real Net::HTTPResponse whose #read_body streams from the Transfer rather
  # than from a socket, so the production code path is unchanged.
  def self.build_streaming_response(code:, headers:, transfer:)
    response = build_response({ code: code, body: "", headers: headers })
    response.instance_variable_set(:@read, false)
    response.instance_variable_set(:@body, nil)

    # Same contract as the real one: once the body has been read, hand it back
    # rather than going to the socket again. Without this, calling #body on the
    # returned response re-streams the transfer with no block.
    response.define_singleton_method(:read_body) do |&block|
      return @body if @read

      transfer.each_chunk { |chunk| block.call(chunk) }
      nil
    end

    response
  end

  # A real Net::HTTPResponse subclass, so `is_a?(Net::HTTPSuccess)` and friends
  # behave exactly as they do against a live server.
  def self.build_response(spec)
    code = spec[:code].to_s
    # The same resolution Net::HTTP itself uses: an exact match, then the class
    # for the leading digit, then unknown. Without the middle step a status the
    # library has no constant for — 418, 451 — would not even be a client error
    # here, which is less faithful than the real thing.
    klass = Net::HTTPResponse::CODE_TO_OBJ[code] ||
            Net::HTTPResponse::CODE_CLASS_TO_OBJ[code[0]] ||
            Net::HTTPUnknownResponse
    response = klass.new("1.1", code, "")

    spec.fetch(:headers, {}).each { |name, value| response[name] = value }
    response.instance_variable_set(:@body, spec[:body].to_s)
    response.instance_variable_set(:@read, true)
    response
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include FakeHttp

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup { sign_in users(:admin) }
end
