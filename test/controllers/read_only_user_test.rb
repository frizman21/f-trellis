require "test_helper"

# A read-only account may read anything and change nothing.
#
# Every write case asserts the underlying state is untouched as well as the
# status code: a 403 that still wrote would be the worst of both outcomes, and
# the status alone cannot tell them apart.
class ReadOnlyUserTest < ActionDispatch::IntegrationTest
  setup do
    @reader = User.create!(email: "reader@example.com", password: "password", read_only: true)
    sign_in @reader

    # Domains stand in for "a resource with an index, a show page, and an edit
    # form a write could be attempted through". This used to be Organization,
    # which no longer exists (#4); what is under test is the verb guard, not
    # the resource, so any full CRUD resource serves.
    @domain = domains(:example_com)
  end

  # --- reading is unaffected ----------------------------------------------

  test "a read-only user can GET an index" do
    get domains_path

    assert_response :success
  end

  test "a read-only user can GET a show page" do
    get domain_path(@domain)

    assert_response :success
    assert_match "example.com", response.body
  end

  test "a read-only user can GET a form, even one it could never submit" do
    get edit_domain_path(@domain)

    assert_response :success
  end

  # The crawl log is diagnostic, so it must stay readable. The guard is by HTTP
  # verb, and this asserts a GET added later did not land behind it.
  test "a read-only user can read a domain's crawl history" do
    FetchRecord.create!(url: "https://example.com/crawled", domain: domains(:example_com),
                        outcome: "http_error", status_code: 404)

    get domain_path(domains(:example_com))

    assert_response :success
    assert_match(/example\.com\/crawled/, response.body)
  end

  # --- writing is refused --------------------------------------------------

  test "PATCH is refused and changes nothing" do
    patch domain_path(@domain), params: { domain: { min_crawl_delay_seconds: 99 } }

    assert_response :forbidden
    assert_equal 1, @domain.reload.min_crawl_delay_seconds
  end

  test "POST is refused and creates nothing" do
    assert_no_difference "Source.count" do
      post sources_path, params: { source: { url: "https://example.com/new-source" } }
    end

    assert_response :forbidden
  end

  test "DELETE is refused and destroys nothing" do
    learning_set = LearningSet.create!(name: "Kept")
    learning_set.learning_set_sources.create!(source: sources(:one))

    assert_no_difference "LearningSetSource.count" do
      delete remove_source_learning_set_path(learning_set), params: { source_id: sources(:one).id }
    end

    assert_response :forbidden
  end

  # Spend is the risk that motivates the flag, so it gets its own case rather
  # than riding on "POST is refused".
  test "queueing processing work is refused and enqueues no job" do
    source = Source.create!(url: "https://example.com/triage-target")
    skill = Skill.create!(name: "Readable", applicability: "Anything.", is_active: true)
    skill.skill_revisions.create!(content: "Do it.")

    assert_no_enqueued_jobs only: ProcessReportJob do
      assert_no_difference "SourceProcessingReport.count" do
        post triage_source_path(source), params: { skill_ids: [ skill.id ] }
      end
    end

    assert_response :forbidden
  end

  test "a JSON write is refused too, not just an HTML one" do
    patch fixture_promotion_path(resource: "sources", id: sources(:one).id),
          params: { is_promotable: true }, as: :json

    assert_response :forbidden
    assert_not sources(:one).reload.is_promotable?
  end

  # --- signing in and out still work --------------------------------------

  test "a read-only user can sign out, which is a DELETE" do
    delete destroy_user_session_path

    assert_response :redirect
    get domains_path
    assert_redirected_to new_user_session_path
  end

  test "a read-only user can sign in, which is a POST" do
    sign_out @reader

    post user_session_path, params: { user: { email: @reader.email, password: "password" } }

    assert_response :redirect
    get domains_path
    assert_response :success
  end

  # --- ordinary accounts are untouched -------------------------------------

  test "a normal user is not restricted on any of those verbs" do
    sign_out @reader
    sign_in users(:admin)

    patch domain_path(@domain), params: { domain: { min_crawl_delay_seconds: 99 } }

    assert_response :redirect
    assert_equal 99, @domain.reload.min_crawl_delay_seconds
  end
end
