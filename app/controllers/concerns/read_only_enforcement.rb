# A read-only account may read anything and change nothing.
#
# The rule is the HTTP verb and nothing else — no per-action list to keep in
# step with the routes. That makes it exactly as strong as the convention that
# GET does not act, which this app does not fully honour yet: see #85, where
# GET /sources/:id/triage is catalogued as the one endpoint that writes and
# spends when merely opened. Simple and slightly leaky beats elaborate and out
# of date; the leak is written down and gets fixed there.
#
# A concern rather than a method on ApplicationController because there are two
# controller trees. Administrate's controllers descend from its engine's own
# controller, not from this application's ApplicationController, so a read-only
# admin would otherwise reach /admin with full write access — the one place in
# the application where that is worst. One copy of the rule, included by both.
module ReadOnlyEnforcement
  extend ActiveSupport::Concern

  READ_ONLY_MESSAGE = "This account is read-only. Only GET requests are permitted.".freeze

  included do
    before_action :block_writes_from_read_only_users
  end

  private

  # Devise's SessionsController is exempt because signing in is itself a POST
  # and signing out a DELETE — Devise controllers inherit from
  # ApplicationController, so without the exemption a read-only account could
  # not log in at all. Only sessions: password changes stay blocked, since these
  # accounts are created and rotated from the console like every other one.
  def block_writes_from_read_only_users
    return if request.get? || request.head?
    return if is_a?(Devise::SessionsController)
    return unless current_user&.read_only?

    respond_to do |format|
      format.json { render json: { error: READ_ONLY_MESSAGE }, status: :forbidden }
      format.any  { render plain: READ_ONLY_MESSAGE, status: :forbidden }
    end
  end
end
