require "test_helper"
require "zip"

class SourceProcessingReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @source = Source.create!(url: "https://reports.test/page")
    @source.update!(status: "complete")
    attach_payload("<html><body><p>Acme Corp</p></body></html>")

    @skill = Skill.create!(name: "Pull orgs")
    @revision = @skill.skill_revisions.create!(content: "Pull the orgs.")
  end

  def attach_payload(html)
    bytes = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry("page.html")
      zos.write(html)
    end
    bytes.rewind

    SourceDatum.create!(source: @source, content_type: "application/zip", data: bytes.read)
  end

  def submit
    post source_processing_reports_path,
         params: { source_processing_report: { source_id: @source.id, skill_id: @skill.id } }
  end

  test "index renders" do
    get source_processing_reports_path
    assert_response :success
  end

  test "the index shows why a failed report failed" do
    SourceProcessingReport.create!(source: @source, skill_revision: @revision,
                                   status: "failed", facts: [],
                                   error: "IOError: provider hung up")

    get source_processing_reports_path

    assert_response :success
    assert_match(/IOError: provider hung up/, response.body)
  end

  # Every report that failed before the column existed has a null error, and the
  # index is the one page that lists them.
  test "the index renders a failed report that recorded no error" do
    SourceProcessingReport.create!(source: @source, skill_revision: @revision,
                                   status: "failed", facts: [], error: nil)

    get source_processing_reports_path

    assert_response :success
    assert_match(/Failed/, response.body)
  end

  test "new renders" do
    get new_source_processing_report_path
    assert_response :success
  end

  test "a first submit creates a report and queues the job" do
    assert_difference "SourceProcessingReport.count", 1 do
      assert_enqueued_jobs 1, only: ProcessReportJob do
        submit
      end
    end

    assert_equal @source.source_data.last.content_hash,
                 SourceProcessingReport.last.content_hash
  end

  test "an identical resubmit creates nothing and queues nothing" do
    submit
    existing = SourceProcessingReport.last

    assert_no_difference "SourceProcessingReport.count" do
      assert_no_enqueued_jobs only: ProcessReportJob do
        submit
      end
    end

    follow_redirect!
    assert_match(/Report ##{existing.id} already covers/, response.body)
  end

  test "a submit after the page content changed does create a new report" do
    submit

    attach_payload("<html><body><p>Acme Corp</p><p>Beta Inc</p></body></html>")

    assert_difference "SourceProcessingReport.count", 1 do
      assert_enqueued_jobs 1, only: ProcessReportJob do
        submit
      end
    end
  end

  test "a re-fetch of unchanged content does not earn a second report" do
    submit

    # Same visible text, different markup — what a re-fetch of a live page looks like.
    attach_payload('<html><body><p class="x" data-ts="9">Acme Corp</p>' \
                   "<script>ads()</script></body></html>")

    assert_no_difference "SourceProcessingReport.count" do
      submit
    end
  end

  test "a different skill on the same content is still allowed" do
    submit

    other = Skill.create!(name: "Other skill")
    other.skill_revisions.create!(content: "Do something else.")

    assert_difference "SourceProcessingReport.count", 1 do
      post source_processing_reports_path,
           params: { source_processing_report: { source_id: @source.id, skill_id: other.id } }
    end
  end

  test "a skill with no revisions is rejected without creating a report" do
    empty = Skill.create!(name: "No revisions")

    assert_no_difference "SourceProcessingReport.count" do
      post source_processing_reports_path,
           params: { source_processing_report: { source_id: @source.id, skill_id: empty.id } }
    end

    follow_redirect!
    assert_match(/has no revisions/, response.body)
  end

  test "the uniqueness rule is enforced at the model too" do
    submit
    hash = @source.source_data.last.content_hash

    duplicate = SourceProcessingReport.new(source: @source, skill_revision: @revision,
                                           status: "new", facts: [], content_hash: hash)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:content_hash], "has already been taken"
  end
end
