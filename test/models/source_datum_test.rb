require "test_helper"
require "zip"
require "stringio"

class SourceDatumTest < ActiveSupport::TestCase
  test "#html decompresses the zip payload" do
    html = "<html><body>hi</body></html>"
    bytes = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry("page.html")
      zos.write(html)
    end
    bytes.rewind

    source = sources(:one)
    datum = SourceDatum.create!(source: source, content_type: "application/zip", data: bytes.read)

    assert_equal html, datum.html
  end

  test "#html returns nil when data is blank" do
    source = sources(:one)
    datum = SourceDatum.new(source: source, content_type: "application/zip", data: nil)
    assert_nil datum.html
  end
end
