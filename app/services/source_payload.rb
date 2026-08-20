require "zip"
require "stringio"
require "uri"

# The single place a fetched payload becomes a SourceDatum row.
#
# A service rather than private methods on FetchSourceJob, which is where this
# lived until #70. Two callers now store content — the job, which just fetched
# it, and the proof of concept's apply stage, which fetched it earlier and has
# it on disk — and two copies of "how bytes become a row" would eventually
# disagree about the container, the entry name, or the content type. Domain
# .for_url exists for the same reason: two places turning a host into a Domain
# would produce two rows for one host.
#
# The payload is zipped because a page is large and mostly repetition. What goes
# in comes back out byte-identical through SourceDatum#raw_bytes, which is the
# property every reader downstream depends on — a PDF in particular must survive
# this untouched, because the parser sees these bytes and nothing else.
class SourcePayload
  # The zip entry's extension. The container is not what the payload is, and a
  # PDF stored as `page.html` misleads anyone who opens the archive.
  FILENAME_SUFFIXES = {
    "text/html"             => [ ".html", ".htm" ],
    "application/xhtml+xml" => [ ".html", ".htm" ],
    "application/pdf"       => [ ".pdf" ]
  }.freeze

  # Assumed when a server sends no Content-Type at all. Some do; refusing them
  # would be stricter than the situation warrants, and the parse path already
  # tolerates whatever it gets.
  DEFAULT_CONTENT_TYPE = "text/html".freeze

  # Store `content` as this source's newest snapshot.
  #
  # A new row every time rather than an update: SourceDatum is a history of what
  # a page said when, and SourceLink hangs off individual snapshots. Callers that
  # must not add a second copy check for one first — that judgement belongs to
  # them, not here.
  def self.store(source:, content:, content_type: DEFAULT_CONTENT_TYPE)
    content_type = content_type.presence || DEFAULT_CONTENT_TYPE

    SourceDatum.create!(
      source: source,
      content_type: content_type,
      data: zip(entry_name_for(source, content_type), content)
    )
  end

  # What the file inside the archive is called. Derived from the URL so an
  # archive opened by hand is navigable, and falling back to the source's id
  # where the URL has no filename to offer — "https://example.com/" has a path
  # of "/" and would otherwise produce an entry named nothing at all.
  def self.entry_name_for(source, content_type = DEFAULT_CONTENT_TYPE)
    basename = File.basename(URI.parse(source.url.to_s).path.to_s)
    basename = "source_#{source.id}" if basename.blank? || basename == "/"

    suffixes = FILENAME_SUFFIXES.fetch(content_type.to_s, FILENAME_SUFFIXES[DEFAULT_CONTENT_TYPE])
    basename.end_with?(*suffixes) ? basename : "#{basename}#{suffixes.first}"
  rescue URI::InvalidURIError
    # A URL that will not parse still has content worth keeping. The entry name
    # is a convenience for a human opening the archive, never an identifier.
    "source_#{source.id}#{FILENAME_SUFFIXES.fetch(content_type.to_s, FILENAME_SUFFIXES[DEFAULT_CONTENT_TYPE]).first}"
  end

  def self.zip(entry_name, content)
    buffer = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry(entry_name)
      zos.write(content)
    end
    buffer.rewind
    buffer.read
  end
end
