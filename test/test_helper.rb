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

    FetchSourceJob.class_eval do
      alias_method :request_without_stub, :request
      define_method(:request) do |uri, extra = {}|
        requests << { uri: uri, headers: request_headers.merge(extra) }
        spec = queue.size > 1 ? queue.shift : queue.first
        raise spec[:raise] if spec[:raise]

        FakeHttp.build_response(spec)
      end
    end

    block.arity.zero? ? yield : yield(requests)
  ensure
    FetchSourceJob.class_eval do
      remove_method :request
      alias_method :request, :request_without_stub
      remove_method :request_without_stub
    end
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
