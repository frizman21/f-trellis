# Motor picks this class up if the application defines it, and falls back to
# "everyone may do everything" if it does not. It is the only seam the engine
# offers for authorisation, and it is what carries this application's read-only
# rule across into it.
#
# ApplicationController refuses any non-GET from a read-only account, but Motor's
# controllers descend from ActionController::Base by way of the engine, not from
# ApplicationController, so that rule stops at the mount. Without this class a
# read-only account that was also an admin would have full write access to every
# table — the one place where losing the restriction would be worst.
#
# Reaching /admin at all already requires is_admin: the mount is wrapped in a
# Devise `authenticate` constraint in routes.rb. So this decides only what an
# admin may do once inside, which is everything unless the account is read-only.
module Motor
  class Ability
    include CanCan::Ability

    def initialize(user)
      if user&.read_only?
        can :read, :all
      else
        can :manage, :all
      end
    end
  end
end
