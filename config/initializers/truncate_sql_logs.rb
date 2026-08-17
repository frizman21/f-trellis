# Keeps the contents of a row out of the line that logs writing it.
#
# A `SourceDatum` insert carries a whole zip archive and a `Message` insert
# carries the full HTML of a crawled page. Logged verbatim, one line reaches
# 64 KB and the trace it was supposed to help you read is buried under it.
#
# The masking Rails already has does not fire, and the reason is not the obvious
# one. `ActiveRecord::LogSubscriber#render_bind` renders a binary value as
# `<N bytes of binary data>` — but only for values passed as *binds*. Setting
# `config.active_record.query_log_tags_enabled` (development.rb) makes Rails set
# `ActiveRecord.disable_prepared_statements = true`, every value is then
# interpolated into the statement string itself, the bind list is empty, and
# `render_bind` is never reached. The leak is a side effect of a convenience
# setting, invisible from the config that enables it.
#
# Fixing it here rather than by turning the query-log tags back off is
# deliberate: restoring binds would mask the zip, but bind values for `text`
# columns are still logged verbatim, so `messages.content` would still spill —
# and we would have given up the annotations that say which job issued a
# statement.
module TruncateSqlLogs
  # Enough to hold an INSERT's table, its column list, and the query-log tag
  # that follows it, and far short of any real payload.
  MAX_STATEMENT = 2_000

  # Binds are individual values, so they need much less room than a whole
  # statement to stay diagnosable.
  MAX_BIND = 500

  # The head names the table and columns; the tail carries `RETURNING` and the
  # query-log tags that say which job issued the statement. Cutting only the
  # tail would throw away the half that answers "who did this", so both ends are
  # kept and the middle — which is where a payload sits — is what goes.
  HEAD_SHARE = 0.7

  ELISION = "… [%d characters elided] …".freeze

  def sql(event)
    statement = event.payload[:sql]

    if statement.is_a?(String) && statement.length > MAX_STATEMENT
      # Merged rather than mutated in place: this payload hash is shared with
      # any other subscriber on `sql.active_record`, and overwriting its `:sql`
      # key would hand a truncated statement to instrumentation that asked for
      # the real one.
      event.payload = event.payload.merge(sql: elide(statement, MAX_STATEMENT))
    end

    super
  end

  private
    # Applied on top of Rails' own rendering, so the binary masking above still
    # runs first and `<N bytes of binary data>` — already short — passes through
    # untouched. This is what makes the cap hold in environments where prepared
    # statements are on, which is test and production today.
    def render_bind(attr, value)
      name, rendered = super

      if rendered.is_a?(String) && rendered.length > MAX_BIND
        rendered = elide(rendered, MAX_BIND)
      end

      [ name, rendered ]
    end

    def elide(string, max)
      head_length = (max * HEAD_SHARE).floor
      tail_length = max - head_length
      dropped     = string.length - max

      "#{string[0, head_length]}#{format(ELISION, dropped)}#{string[-tail_length..]}"
    end
end

# Deferred rather than referenced at file scope so the initializer does not
# force ActiveRecord to load just to attach to it.
ActiveSupport.on_load(:active_record) do
  ActiveRecord::LogSubscriber.prepend(TruncateSqlLogs)
end
