require "test_helper"

# The gate on /admin. Motor::Admin is a mounted engine whose screens are the
# gem's own, so what is worth testing is who gets through the mount and what
# they may do once inside — not the CRUD itself.
class BackOfficeAccessTest < ActionDispatch::IntegrationTest
  test "an admin reaches the back office" do
    get motor_admin_path

    assert_response :success
  end

  # The mount is wrapped in a Devise `authenticate` constraint, so a non-admin
  # matches no route at all. 404 rather than 403 is the point: a 403 would
  # confirm the interface is there and that they are the wrong kind of account.
  test "a signed-in non-admin is not found" do
    sign_in_as users(:other)

    get motor_admin_path

    assert_response :not_found
  end

  test "a signed-in non-admin is not found anywhere under the mount" do
    sign_in_as users(:other)

    get "#{motor_admin_path}/data/users"

    assert_response :not_found
  end

  # Devise's `authenticate` separates the two cases: no session at all is sent
  # to sign in, while a session belonging to the wrong kind of account 404s.
  # Both are wanted, and they are not the same answer.
  test "a signed-out request is sent to sign in" do
    # Read before the request, not after. Once a request has gone into the
    # mounted engine, the url helpers in this test resolve against it, and
    # new_user_session_path starts naming /admin/users/sign_in — which is the
    # test's own context leaking, not anything the application does.
    sign_in_path = new_user_session_path

    sign_out users(:admin)

    get motor_admin_path

    assert_response :redirect
    assert_equal sign_in_path, URI.parse(response.location).path

    # Following it is what says the destination is real rather than merely
    # well-named.
    follow_redirect!

    assert_response :success
    assert_select "form[action=?]", sign_in_path
  end

  # ApplicationController's verb rule stops at the mount — the engine's
  # controllers descend from ActionController::Base, not from it. Motor::Ability
  # is what carries the restriction across, and these are what say it arrived.
  test "a read-only admin may read" do
    assert Motor::Ability.new(read_only_admin).can?(:read, User)
  end

  test "a read-only admin may not write" do
    ability = Motor::Ability.new(read_only_admin)

    assert_not ability.can?(:create, User)
    assert_not ability.can?(:update, User)
    assert_not ability.can?(:destroy, User)
  end

  test "an ordinary admin may write" do
    ability = Motor::Ability.new(users(:admin))

    assert ability.can?(:manage, User)
  end

  # The ability object is the mechanism; this is the engine consulting it.
  # Asserting only on Motor::Ability would still pass if the engine stopped
  # asking. Refusal surfaces here as the raised CanCan error rather than a 403
  # because the test environment only rescues exceptions with a mapped
  # response; over real HTTP the engine rescues it into a JSON 403, which was
  # checked by hand against the running container.
  test "a read-only admin is refused a write by the engine" do
    sign_in_as read_only_admin

    assert_no_difference -> { User.count } do
      assert_raises CanCan::AccessDenied do
        post_a_user
      end
    end
  end

  test "an admin who is not read-only is not refused by the same path" do
    refused = begin
      post_a_user
      false
    rescue CanCan::AccessDenied
      true
    rescue StandardError
      # Anything else is the engine's opinion of the payload, not an
      # authorisation refusal, and is not what this is asking about.
      false
    end

    assert_not refused, "an ordinary admin was refused a write in the back office"
  end

  # audited comes in with motor-admin and installs its sweeper on
  # ActionController::Base itself, which calls controller.try(:request) on every
  # request in the application. ModelEndpointsController has an action named
  # `try`, so that call raised and the "try it" screen died — 22 tests, in a
  # feature with nothing to do with the back office. An initializer moves the
  # sweeper onto motor's controller alone; these say it stayed moved.
  test "the audited sweeper is not installed on the application's controllers" do
    sweepers = ActionController::Base._process_action_callbacks
                                     .select { |callback| callback.filter.is_a?(Audited::Sweeper) }

    assert_empty sweepers,
                 "audited's sweeper is back on ActionController::Base and will " \
                 "break any controller with an action named `try`"
  end

  test "the audited sweeper is installed on motor's controller" do
    sweepers = Motor::ApplicationController._process_action_callbacks
                                           .select { |callback| callback.filter.is_a?(Audited::Sweeper) }

    assert_not_empty sweepers, "motor lost the attribution its audit trail depends on"
  end

  # The action that the sweeper's `try` call collided with. Kept here rather
  # than only in the endpoint's own suite so the reason it matters is written
  # down beside the cause.
  test "a controller action named try still works" do
    endpoint = ModelEndpoint.create!(name: "sweeper-check", base_url: "https://example.com")

    post try_model_endpoint_path(endpoint), params: { prompt: "" }

    assert_response :success
  end

  private

  def post_a_user
    post "#{motor_admin_path}/api/data/users",
         params: { data: { email: "written@example.com" } }.to_json,
         headers: { "Content-Type" => "application/json" }
  end

  def sign_in_as(user)
    sign_out users(:admin)
    sign_in user
  end

  def read_only_admin
    @read_only_admin ||= User.create!(email: "readonly-admin@example.com",
                                      password: "password",
                                      is_admin: true, read_only: true)
  end
end
