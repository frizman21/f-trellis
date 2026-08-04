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
end
