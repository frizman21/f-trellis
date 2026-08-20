# Where one recorded fact came from: every sighting of it, with the source that
# stated it and the run that saw it.
#
# One controller for four kinds of fact rather than four controllers, because
# the question is the same in every case and only the table differs. The kind is
# a path segment, checked against KINDS — an unknown one is a 404 rather than a
# lookup against a class named by the URL.
class PedigreesController < ApplicationController
  # kind => the project association to find it in, and the citations to show.
  #
  # Found through the project rather than by id alone: every one of these
  # carries project_id (see ScopedToProject), so an id from another project is a
  # 404 by construction rather than by a check someone has to remember.
  KINDS = {
    "entity" => { scope: :entities, citations: :entity_extraction_runs },
    "entity-value" => { scope: :entity_attribute_values,
                        citations: :entity_attribute_value_extraction_runs },
    "relationship" => { scope: :relationships, citations: :relationship_extraction_runs },
    "relationship-value" => { scope: :relationship_type_values,
                              citations: :relationship_type_value_extraction_runs }
  }.freeze

  def show
    @project = Project.find(params[:project_id])
    kind = KINDS.fetch(params[:kind]) { raise ActionController::RoutingError, "unknown pedigree kind" }

    @record = @project.public_send(kind[:scope]).find(params[:id])
    # Newest first: the last thing to say something is usually what you came to
    # check. Ordered by the run rather than by the citation so two facts seen in
    # one run read as one event.
    @citations = @record.public_send(kind[:citations])
                        .includes(:source, extraction_run: %i[model source])
                        .order(created_at: :desc)
  end
end
