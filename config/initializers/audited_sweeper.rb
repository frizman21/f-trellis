# audited arrives as a motor-admin dependency and installs its sweeper as an
# around_action on ActionController::Base itself, so it runs on every controller
# in this application — including the ones it knows nothing about. The sweeper
# calls `controller.try(:request)`, and ModelEndpointsController has an action
# named `try`, which shadows Object#try and turns that call into an
# ArgumentError. It took out the whole "try it" screen the moment motor-admin
# was added.
#
# The sweeper's job is to attribute audit records to a user and a request, and
# motor is the only thing here that writes audit records. So it moves onto
# motor's own controller and comes off everybody else's: motor keeps its
# attribution, and the rest of the application is left as it was.
#
# to_prepare rather than after_initialize because motor's controller is
# reloadable in development, and a callback added once at boot would not survive
# the first reload.
Rails.application.config.to_prepare do
  installed = ActionController::Base._process_action_callbacks
                                    .select { |callback| callback.filter.is_a?(Audited::Sweeper) }
                                    .map(&:filter)

  installed.each { |sweeper| ActionController::Base.skip_around_action(sweeper) }

  Motor::ApplicationController.around_action(Audited::Sweeper.new)
end
