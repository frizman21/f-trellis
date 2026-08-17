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

    @organization = Organization.create!
    @report = SourceProcessingReport.create!(
      source: sources(:one), skill_revision: skill_revisions(:promoted_1), status: "complete"
    )
    @detail = OrganizationDetail.create!(
      organization: @organization, source_processing_report: @report,
      name: "National Aeronautics and Space Administration", acronym: "NASA",
      as_of: Time.zone.parse("1958-07-29"), confidence_tenths: 1000
    )
    @organization.update!(current_detail: @detail)
  end

  # --- reading is unaffected ----------------------------------------------

  test "a read-only user can GET an index" do
    get organizations_path

    assert_response :success
  end

  test "a read-only user can GET a show page" do
    get organization_path(@organization)

    assert_response :success
    assert_match "NASA", response.body
  end

  test "a read-only user can GET a form, even one it could never submit" do
    get edit_organization_path(@organization)

    assert_response :success
  end

  # The crawl log is diagnostic, so it must stay readable. The guard is by HTTP
  # verb, and this asserts a GET added later did not land behind it.
  test "a read-only user can read a domain's crawl history" do
    CrawlRecord.create!(url: "https://example.com/crawled", domain: domains(:example_com),
                        outcome: "http_error", status_code: 404)

    get domain_path(domains(:example_com))

    assert_response :success
    assert_match(/example\.com\/crawled/, response.body)
  end

  # --- writing is refused --------------------------------------------------

  test "PATCH is refused and changes nothing" do
    patch organization_path(@organization), params: { organization: { acronym: "CHANGED" } }

    assert_response :forbidden
    assert_equal "NASA", @detail.reload.acronym
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
    get organizations_path
    assert_redirected_to new_user_session_path
  end

  test "a read-only user can sign in, which is a POST" do
    sign_out @reader

    post user_session_path, params: { user: { email: @reader.email, password: "password" } }

    assert_response :redirect
    get organizations_path
    assert_response :success
  end

  # --- ordinary accounts are untouched -------------------------------------

  test "a normal user is not restricted on any of those verbs" do
    sign_out @reader
    sign_in users(:admin)

    patch organization_path(@organization), params: { organization: { acronym: "CHANGED" } }

    assert_response :redirect
    assert_equal "CHANGED", @detail.reload.acronym
  end
end
