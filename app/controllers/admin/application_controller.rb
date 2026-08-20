# Every Administrate controller inherits from this one, which is where the gate
# on /admin lives.
#
# It is not in this application's ApplicationController tree: Administrate's
# controllers descend from its engine's own base class. Nothing that
# ApplicationController does reaches here, so authentication and the read-only
# rule are both stated again — the latter by including the same concern rather
# than by a second copy of the rule.
module Admin
  class ApplicationController < Administrate::ApplicationController
    before_action :authenticate_user!
    before_action :require_admin

    include ReadOnlyEnforcement

    private

    # 404 rather than 403, and rendered by the same exception a missing record
    # raises. A 403 tells a signed-in non-admin that /admin is there and that
    # they are the wrong kind of account, which is more than they need to know
    # about an interface that can write every table. To an account that may not
    # use it, it simply does not exist.
    def require_admin
      raise ActiveRecord::RecordNotFound unless current_user&.is_admin?
    end
  end
end
