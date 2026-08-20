class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!

  # Declares before_action :block_writes_from_read_only_users. Shared with
  # Admin::ApplicationController, which is not in this tree.
  include ReadOnlyEnforcement

  # The project the current page is inside, or nil outside one. Set by the
  # scoped controllers; exposed so the banner is driven by the same object the
  # page is, rather than by a second lookup or a controller-name check.
  def current_project = @project
  helper_method :current_project
end
