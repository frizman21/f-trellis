# Correcting a run whose worker died.
#
# In development the async queue adapter keeps jobs in the server's own threads,
# so every restart — a branch switch, a migration, a Gemfile change — takes the
# in-flight ones with it and leaves the row saying `running` forever. Reading
# the page already stops such a run blocking anything; this is how the row
# itself is put right.
module Projects
  class ExtractionRunsController < ApplicationController
    def abandon
      project = Project.find(params[:project_id])
      run = project.extraction_runs.find(params[:id])

      # Only what has already given up. Marking a live run failed would be
      # overwritten minutes later when ExtractionJob finishes and calls
      # `run.update!`, leaving the screen and the database disagreeing.
      unless run.stalled?
        return redirect_to project_source_path(project, run.source),
                           alert: "That run is still within the time a call can take. Leave it be."
      end

      run.update!(status: "failed", completed_at: Time.current,
                  error: "Abandoned after #{minutes(run)} minutes with no answer. " \
                         "The worker was most likely restarted.")

      redirect_to project_source_path(project, run.source),
                  notice: "Run ##{run.id} marked as failed."
    end

    private

    def minutes(run) = (run.elapsed / 60).round
  end
end
