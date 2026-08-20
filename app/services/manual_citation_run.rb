# The run a person's own edit belongs to.
#
# Every citation names an extraction run since #71, including the ones people
# record by hand in the entity and relationship forms. Those have a source and a
# confidence and no run, so one is made for them here.
#
# One run per submission *per source*, not one per submission: a run names a
# single source, and one save can cite several — the entity to one page and an
# attribute value to another. Grouping by source is what makes "each save is a
# sighting" true without stretching what a run is.
#
# Fresh every time rather than reused, because that is the whole point: editing
# the same entity twice is two sightings, and a found-and-reused run would
# collapse them into one and lose the second.
class ManualCitationRun
  # Citations that have a source chosen and no run yet. An existing row being
  # edited already belongs to the run that first recorded it, and must keep it —
  # changing its confidence does not make it a new sighting.
  def self.stamp!(project:, citations:)
    Array(citations)
      .select { |citation| citation.extraction_run.nil? && citation.source_id.present? }
      .group_by(&:source_id)
      .each do |source_id, group|
        run = ExtractionRun.manual(project: project, source_id: source_id)
        group.each { |citation| citation.extraction_run = run }
      end
  end
end
