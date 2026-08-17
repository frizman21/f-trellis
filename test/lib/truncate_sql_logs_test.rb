require "test_helper"
require "stringio"

# Driven through ActiveSupport::Notifications with a real logger rather than by
# calling the helper directly, so the assertions are about a log line that was
# actually emitted — the prepend landing on the wrong class, or the initializer
# never running, both show up here.
class TruncateSqlLogsTest < ActiveSupport::TestCase
  # A realistic head and tail around whatever payload a case supplies. The tail
  # is the part a naive "cut the end off" fix would lose.
  OPENING = "INSERT INTO \"source_data\" (\"content_type\", \"created_at\", \"data\", \"source_id\", \"updated_at\", \"content_hash\") VALUES ('application/zip', '2026-08-17 15:20:43.703334', '".freeze
  CLOSING = "', 1, '2026-08-17 15:20:43.703334', 'abc') RETURNING \"id\" /*application='App',job='FetchSourceJob'*/".freeze

  # The zip local-file-header magic, which is what made the reported line
  # identifiable as an archive in the first place.
  ZIP_MAGIC = "504b0304".freeze

  setup do
    @colorize = ActiveSupport::LogSubscriber.colorize_logging
    ActiveSupport::LogSubscriber.colorize_logging = false
  end

  teardown do
    ActiveSupport::LogSubscriber.colorize_logging = @colorize
  end

  test "a statement under the cap is logged unchanged" do
    statement = %(SELECT "sources".* FROM "sources" WHERE "sources"."id" = 1 LIMIT 1)

    line = log_line_for(sql: statement)

    assert_includes line, statement
    assert_not_includes line, "characters elided"
  end

  test "a statement over the cap keeps its opening, its closing and a count of what was dropped" do
    statement = OPENING + ("a" * 50_000) + CLOSING

    line = log_line_for(sql: statement)

    assert_includes line, %(INSERT INTO "source_data")
    assert_includes line, %(RETURNING "id")
    assert_includes line, %(/*application='App',job='FetchSourceJob'*/)

    dropped = statement.length - TruncateSqlLogs::MAX_STATEMENT
    assert_includes line, "[#{dropped} characters elided]"
  end

  test "a statement over the cap is logged at roughly the cap" do
    statement = OPENING + ("a" * 50_000) + CLOSING

    line = log_line_for(sql: statement)

    # The cap plus the elision marker and the subscriber's own name prefix, not
    # the 50 KB that went in.
    assert_operator line.length, :<, TruncateSqlLogs::MAX_STATEMENT + 200
  end

  test "a hex-encoded zip payload does not reach the log" do
    # 64 KB of archive, the size of the line that prompted this.
    hex       = "\\x" + (ZIP_MAGIC * 8_000)
    statement = OPENING + hex + CLOSING

    line = log_line_for(sql: statement)

    assert_operator line.length, :<, 4_096, "the reported defect: a single 64 KB log line"

    # Keeping head and tail necessarily keeps the bytes adjacent to them, so the
    # claim is not that no byte of the archive survives — it is that what
    # survives is bounded by the cap rather than by the size of the archive.
    before = statement.scan(ZIP_MAGIC).length
    after  = line.scan(ZIP_MAGIC).length

    assert_operator after, :<=, TruncateSqlLogs::MAX_STATEMENT / ZIP_MAGIC.length
    assert_operator after, :<, before / 20, "expected the archive to be elided, not merely trimmed"

    assert_includes line, %(RETURNING "id"), "the tail that says which job did this must survive"
  end

  test "a bind longer than the cap is elided and a short one is untouched" do
    long  = "x" * 5_000
    short = "a short value"

    line = log_line_for(**string_bind(long))
    assert_includes line, "characters elided"
    assert_not_includes line, long

    line = log_line_for(**string_bind(short))
    assert_includes line, short
    assert_not_includes line, "characters elided"
  end

  test "a binary bind still renders as Rails' byte count rather than generic truncation" do
    bytes = "\x50\x4b\x03\x04".b * 5_000
    attr  = ActiveModel::Attribute.from_database("data", bytes, ActiveRecord::Type::Binary.new)

    line = log_line_for(sql: %(INSERT INTO "source_data" ("data") VALUES ($1)),
                        binds: [ attr ], type_casted_binds: [ bytes ])

    assert_includes line, "bytes of binary data>",
                    "the existing Rails masking must survive the prepend"
    assert_not_includes line, "characters elided"
  end

  private

  def string_bind(value)
    attr = ActiveModel::Attribute.from_database("content", value, ActiveModel::Type::String.new)

    { sql: %(INSERT INTO "messages" ("content") VALUES ($1)),
      binds: [ attr ], type_casted_binds: [ value ] }
  end

  # Swaps in a logger we can read back, emits one event, and returns the line
  # that event produced. Other queries the test transaction happens to run are
  # filtered out by the payload name rather than by position.
  def log_line_for(**payload)
    io       = StringIO.new
    logger   = ActiveSupport::Logger.new(io)
    logger.level = :debug

    original = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = logger

    ActiveSupport::Notifications.instrument("sql.active_record",
                                            name: "SourceDatum Create",
                                            connection: ActiveRecord::Base.lease_connection,
                                            **payload)

    io.string.lines.find { |l| l.include?("SourceDatum Create") }.to_s
  ensure
    ActiveRecord::Base.logger = original
  end
end
