class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :block_writes_from_read_only_users

  READ_ONLY_MESSAGE = "This account is read-only. Only GET requests are permitted.".freeze

  # The project the current page is inside, or nil outside one. Set by the
  # scoped controllers; exposed so the banner is driven by the same object the
  # page is, rather than by a second lookup or a controller-name check.
  def current_project = @project
  helper_method :current_project

  private

  # A read-only account may read anything and change nothing.
  #
  # The rule is the HTTP verb and nothing else — no per-action list to keep in
  # step with the routes. That makes it exactly as strong as the convention that
  # GET does not act, which this app does not fully honour yet: see #85, where
  # GET /sources/:id/triage is catalogued as the one endpoint that writes and
  # spends when merely opened. Simple and slightly leaky beats elaborate and
  # out of date; the leak is written down and gets fixed there.
  #
  # Devise's SessionsController is exempt because signing in is itself a POST
  # and signing out a DELETE — Devise controllers inherit from this one, so
  # without the exemption a read-only account could not log in at all. Only
  # sessions: password changes stay blocked, since these accounts are created
  # and rotated from the console like every other one.
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
