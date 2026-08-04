require "test_helper"

# The change request asks for a facility to see which commit is running, so what
# matters is that it reaches the page — every page. The branches of the badge
# itself are covered in ApplicationHelperTest.
class AppVersionDisplayTest < ActionDispatch::IntegrationTest
  SHA = "0123456789abcdef0123456789abcdef01234567".freeze

  setup do
    @original_git_rev = ENV["GIT_REV"]
    ENV["GIT_REV"] = SHA
  end

  teardown do
    if @original_git_rev.nil?
      ENV.delete("GIT_REV")
    else
      ENV["GIT_REV"] = @original_git_rev
    end
  end

  test "the running commit appears on a signed-in page" do
    get people_path

    assert_response :success
    assert_select "a[href=?]", "https://github.com/frizman21/f-dod/commit/#{SHA}", text: "012345"
  end

  test "the running commit appears while signed out" do
    sign_out :user

    get new_user_session_path

    assert_response :success
    assert_select "a", text: "012345"
  end

  test "the sha is shortened to six characters, not the full forty" do
    get people_path

    assert_response :success
    assert_select "a", text: "012345"
    assert_no_match SHA, response.body.gsub(%r{https://github\.com/\S+}, "")
  end
end
