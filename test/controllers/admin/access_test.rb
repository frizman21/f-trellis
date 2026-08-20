require "test_helper"

# The gate on /admin, which is the part of this worth testing. The CRUD screens
# themselves are generated code, and asserting on them would be asserting on
# Administrate.
class Admin::AccessTest < ActionDispatch::IntegrationTest
  test "an admin reaches the dashboard root" do
    get admin_root_path

    assert_response :success
  end

  test "an admin reaches a resource index" do
    get admin_sources_path

    assert_response :success
  end

  test "an admin reaches a resource's new form" do
    get new_admin_source_path

    assert_response :success
  end

  # 404 rather than 403: an account that may not use /admin is not told it is
  # there.
  test "a signed-in non-admin is not found at the dashboard root" do
    sign_in_as_non_admin

    get admin_root_path

    assert_response :not_found
  end

  test "a signed-in non-admin is not found at a resource index" do
    sign_in_as_non_admin

    get admin_sources_path

    assert_response :not_found
  end

  test "a signed-in non-admin is not found at a resource's new form" do
    sign_in_as_non_admin

    get new_admin_source_path

    assert_response :not_found
  end

  test "a signed-in non-admin cannot create through it" do
    sign_in_as_non_admin

    assert_no_difference -> { Source.count } do
      post admin_sources_path, params: { source: { url: "https://example.com/x" } }
    end

    assert_response :not_found
  end

  test "a signed-out request is sent to sign in" do
    sign_out users(:admin)

    get admin_root_path

    assert_redirected_to new_user_session_path
  end

  # ApplicationController's read-only rule does not reach Administrate's
  # controllers, which descend from its engine rather than from this
  # application. The concern is what carries it across; these two are what say
  # it arrived.
  test "a read-only admin can read every page" do
    sign_in_as(read_only_admin)

    get admin_root_path
    assert_response :success

    get admin_sources_path
    assert_response :success
  end

  test "a read-only admin is refused on a write" do
    sign_in_as(read_only_admin)

    assert_no_difference -> { Source.count } do
      post admin_sources_path, params: { source: { url: "https://example.com/y" } }
    end

    assert_response :forbidden
    assert_match(/read-only/, response.body)
  end

  private

  def sign_in_as_non_admin
    sign_in_as(users(:other))
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
