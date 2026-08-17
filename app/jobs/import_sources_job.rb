# Turns a pasted list of URLs into Sources.
#
# Two things about this job are decisions rather than mechanics, and both are
# the reason it is not a loop over Source.for_url:
#
# 1. Nothing is fetched. Source.for_url calls queue_initial_fetch, so the
#    ordinary creation path would put two thousand fetch jobs on the queue at
#    once. CrawlPacer scopes to a single CrawlJob, so those requests would not
#    be paced against one another at all, and a bulk paste would become an
#    unpaced burst at every host in the list. Link extraction already made this
#    call at a tenth of the scale; see Source#queue_initial_fetch.
#
# 2. One bad line does not cost the paste. Every rejection is recorded against
#    the import with its reason and the walk continues, because the alternative
#    is asking somebody to find the one malformed row in two thousand.
class ImportSourcesJob < ApplicationJob
  queue_as :default

  # Existing URLs are looked up a batch at a time, so the query count scales
  # with the number of batches rather than with the size of the paste.
  BATCH_SIZE = 500

  def perform(import)
    import.update!(status: "running")

    urls     = import.submitted_urls
    created  = 0
    existing = 0
    rejected = []

    urls.each_slice(BATCH_SIZE) do |batch|
      normalized = batch.map { |line| [ line, Source.normalize_url(line) ] }

      normalized.each do |line, url|
        if url.nil?
          rejected << { "value" => line, "reason" => "not a usable web address" }
          next
        end

        # Read inside the loop rather than once per batch: a URL repeated within
        # one paste has to see the row the earlier line just created, or the
        # counts stop adding up to submitted_count.
        if Source.exists?(url: url)
          existing += 1
          next
        end

        begin
          Source.create!(url: url, description: "Bulk import ##{import.id}")
          created += 1
        rescue ActiveRecord::RecordInvalid => e
          # The usual arrival here is a URL that survived normalisation but
          # whose host will not resolve to a Domain.
          rejected << { "value" => line, "reason" => e.record.errors.full_messages.to_sentence }
        end
      end
    end

    import.update!(status: "complete",
                   submitted_count: urls.size,
                   created_count: created,
                   existing_count: existing,
                   rejected: rejected)
  rescue StandardError => e
    # Without this an import that blew up part way sits at "running" forever,
    # which is indistinguishable from one still in progress.
    import.update_columns(status: "failed", error_message: "#{e.class}: #{e.message}")
    Rails.logger.error("ImportSourcesJob failed for import ##{import.id}: #{e.class}: #{e.message}")
    raise
  end
end
