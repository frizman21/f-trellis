require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "an account is not read-only unless it is made so" do
    user = User.create!(email: "fresh@example.com", password: "password")

    assert_not user.read_only?
  end

  test "existing accounts are unaffected by the default" do
    assert_not users(:admin).read_only?
    assert_not users(:other).read_only?
  end

  test "an account is not an admin unless it is made so" do
    user = User.create!(email: "fresh-admin@example.com", password: "password")

    assert_not user.is_admin?
  end

  test "the admin flag is not backfilled onto existing accounts" do
    assert_not users(:other).is_admin?
  end

  # The two flags answer different questions, so an account can hold both: it
  # reaches every /admin page and is refused on every write there.
  test "the admin and read-only flags are independent" do
    user = User.create!(email: "both@example.com", password: "password",
                        is_admin: true, read_only: true)

    assert user.is_admin?
    assert user.read_only?
  end
end
