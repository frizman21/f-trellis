require "test_helper"

class SourceProcessingReportsHelperTest < ActionView::TestCase
  def report(status:, error: nil)
    SourceProcessingReport.new(status: status, error: error)
  end

  test "report_status_cell is the badge alone when nothing failed" do
    cell = report_status_cell(report(status: "complete"))

    assert_match(/badge bg-success/, cell)
    assert_match(/Complete/, cell)
    assert_no_match(/text-danger/, cell)
  end

  test "report_status_cell carries the reason a run failed" do
    cell = report_status_cell(report(status: "failed", error: "IOError: provider hung up"))

    assert_match(/badge bg-danger/, cell)
    assert_match(/IOError: provider hung up/, cell)
  end

  test "report_status_cell falls back to a neutral badge for an unknown status" do
    assert_match(/badge bg-secondary/, report_status_cell(report(status: "queued")))
  end

  # The message is provider text, echoed back into a page. It is markup only if
  # something escapes it.
  test "report_status_cell escapes the message" do
    cell = report_status_cell(report(status: "failed", error: "<script>alert(1)</script>"))

    assert_no_match(/<script>/, cell)
    assert_match(/&lt;script&gt;/, cell)
  end
end
