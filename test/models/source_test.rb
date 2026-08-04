require "test_helper"

class SourceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "auto-creates a domain from the url on save" do
    assert_difference -> { Domain.count } => 1 do
      source = Source.create!(url: "https://newhost.example/path", description: "x")
      assert_equal "newhost.example", source.domain.host
    end
  end

  test "reuses an existing domain matching the url host" do
    Domain.create!(host: "reuse.test")
    assert_no_difference -> { Domain.count } do
      source = Source.create!(url: "https://reuse.test/page", description: "x")
      assert_equal "reuse.test", source.domain.host
    end
  end

  test "downcases host when deriving the domain" do
    source = Source.create!(url: "https://MixedCase.Example/path", description: "x")
    assert_equal "mixedcase.example", source.domain.host
  end

  test "explicit domain assignment is not overridden" do
    explicit = Domain.create!(host: "explicit.test")
    source = Source.create!(url: "https://other.test/page", domain: explicit, description: "x")
    assert_equal "explicit.test", source.domain.host
  end

  test "fails validation when url has no parseable host" do
    source = Source.new(url: "not a url at all", description: "x")
    assert_not source.valid?
    assert_includes source.errors[:domain], "must exist"
  end

  # --- for_url and the initial fetch ---------------------------------------

  test "for_url queues a fetch for a page it had to create" do
    assert_enqueued_jobs 1, only: FetchSourceJob do
      source = Source.for_url("https://example.com/brand-new")
      assert_equal "new", source.status
    end
  end

  # Reusing a row is not creating one. A page already fetched must not be pulled
  # again because somebody filed it into a second learning set.
  test "for_url queues nothing when the page already exists" do
    Source.create!(url: "https://example.com/known")

    assert_no_enqueued_jobs only: FetchSourceJob do
      Source.for_url("https://example.com/known")
    end
  end

  test "for_url queues nothing for text that is not a usable url" do
    assert_no_enqueued_jobs only: FetchSourceJob do
      assert_nil Source.for_url("not a url")
    end
  end

  # The guard on moving this to an after_create callback: plain creation is the
  # path crawls and link extraction use, and neither wants an outbound request.
  test "creating a source directly queues nothing" do
    assert_no_enqueued_jobs only: FetchSourceJob do
      Source.create!(url: "https://example.com/quiet")
    end
  end

  test "parent_source is optional" do
    source = Source.new(url: "https://example.com/no-parent")

    assert source.valid?
    assert_nil source.parent_source
  end

  test "child_sources reports the sources discovered from this one" do
    parent = sources(:one)
    child  = Source.create!(url: "https://example.com/child", parent_source: parent)

    assert_equal parent, child.parent_source
    assert_includes parent.child_sources, child
  end

  test "destroying a parent nullifies its children rather than deleting them" do
    parent = Source.create!(url: "https://example.com/parent")
    child  = Source.create!(url: "https://example.com/child", parent_source: parent)

    parent.destroy

    assert Source.exists?(child.id), "expected the child source to survive"
    assert_nil child.reload.parent_source_id
  end
end
