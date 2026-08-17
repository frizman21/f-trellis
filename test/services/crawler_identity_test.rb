require "test_helper"

class CrawlerIdentityTest < ActiveSupport::TestCase
  # ENV is process-global and the suite runs in parallel processes, so every
  # key touched here is restored whatever the test does.
  def with_env(values)
    previous = values.keys.index_with { |key| ENV.key?(key) ? ENV[key] : :absent }

    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each do |key, value|
      value == :absent ? ENV.delete(key) : ENV[key] = value
    end
  end

  # Minitest 6 no longer ships minitest/mock, so this is the same alias_method
  # stubbing the rest of the suite uses.
  def with_version(version)
    AppVersion.singleton_class.class_eval do
      alias_method :short_without_stub, :short
      define_method(:short) { |git_dir: nil| version }
    end
    yield
  ensure
    AppVersion.singleton_class.class_eval do
      remove_method :short
      alias_method :short, :short_without_stub
      remove_method :short_without_stub
    end
  end

  def unconfigured(&block)
    with_env("CRAWLER_USER_AGENT" => nil, "CRAWLER_CONTACT_URL" => nil, &block)
  end

  test "default carries the name, the version and the contact URL" do
    unconfigured do
      with_version("abc123") do
        assert_equal "f-agents/abc123 (+https://github.com/f-agents)", CrawlerIdentity.user_agent
      end
    end
  end

  # The app is f-dod; the crawler is deliberately not. Asserted on its own
  # because this is the value someone will otherwise "fix" to match the app.
  test "identifies as f-agents, not f-dod" do
    unconfigured do
      with_version("abc123") do
        assert_includes CrawlerIdentity.user_agent, "f-agents"
        assert_not_includes CrawlerIdentity.user_agent, "f-dod"
      end
    end
  end

  test "omits the version when it cannot be determined" do
    unconfigured do
      with_version(nil) do
        assert_equal "f-agents (+https://github.com/f-agents)", CrawlerIdentity.user_agent
      end
    end
  end

  test "CRAWLER_USER_AGENT replaces the agent but keeps the contact URL" do
    with_env("CRAWLER_USER_AGENT" => "custom-bot/2.0", "CRAWLER_CONTACT_URL" => nil) do
      assert_equal "custom-bot/2.0 (+https://github.com/f-agents)", CrawlerIdentity.user_agent
    end
  end

  test "CRAWLER_CONTACT_URL replaces the destination" do
    with_env("CRAWLER_USER_AGENT" => nil, "CRAWLER_CONTACT_URL" => "https://example.com/bot") do
      with_version("abc123") do
        assert_equal "f-agents/abc123 (+https://example.com/bot)", CrawlerIdentity.user_agent
      end
    end
  end

  # An empty contact URL is an explicit "none", distinct from an absent one.
  test "an explicitly blank contact URL omits the parentheses" do
    with_env("CRAWLER_USER_AGENT" => nil, "CRAWLER_CONTACT_URL" => "") do
      with_version("abc123") do
        assert_equal "f-agents/abc123", CrawlerIdentity.user_agent
      end
    end
  end

  test "an agent that already carries a contact URL is not appended to twice" do
    with_env("CRAWLER_USER_AGENT" => "custom-bot/2.0 (+https://example.com/bot)",
             "CRAWLER_CONTACT_URL" => nil) do
      assert_equal "custom-bot/2.0 (+https://example.com/bot)", CrawlerIdentity.user_agent
    end
  end

  test "a blank CRAWLER_USER_AGENT falls back to the default rather than sending nothing" do
    with_env("CRAWLER_USER_AGENT" => "   ", "CRAWLER_CONTACT_URL" => nil) do
      with_version("abc123") do
        assert_equal "f-agents/abc123 (+https://github.com/f-agents)", CrawlerIdentity.user_agent
      end
    end
  end

  # The value is operator-supplied and goes straight into a request header.
  test "newlines and control characters are stripped from configured values" do
    with_env("CRAWLER_USER_AGENT" => "evil/1.0\r\nX-Injected: yes",
             "CRAWLER_CONTACT_URL" => "https://example.com/bot\nX-Also: no") do
      agent = CrawlerIdentity.user_agent

      assert_not_includes agent, "\r"
      assert_not_includes agent, "\n"
      assert_equal "evil/1.0X-Injected: yes (+https://example.com/botX-Also: no)", agent
    end
  end
end
