require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "index lists every user's email" do
    get users_path

    assert_response :success
    assert_select "h1", "Users"
    User.pluck(:email).each { |email| assert_select "td", text: email }
  end

  # The read-only flag is enforced on every non-GET request, so it is the one
  # thing about an account worth stating.
  test "index marks read-only accounts" do
    reader = User.create!(email: "reader@example.com", password: "password", read_only: true)

    get users_path

    assert_select "tbody tr" do |rows|
      row = rows.detect { |r| r.text.include?(reader.email) }
      assert_match(/read-only/, row.text)

      normal = rows.detect { |r| r.text.include?(users(:admin).email) }
      assert_match(/full/, normal.text)
    end
  end

  test "index is ordered by email" do
    User.create!(email: "aaa@example.com", password: "password")
    User.create!(email: "zzz@example.com", password: "password")

    get users_path

    emails = css_select("tbody tr td:first-child").map { |td| td.text.strip }
    assert_equal emails.sort, emails
  end

  # Viewing is a GET, and the read-only rule is about writes.
  test "a read-only user can view it" do
    reader = User.create!(email: "reader2@example.com", password: "password", read_only: true)
    sign_out users(:admin)
    sign_in reader

    get users_path

    assert_response :success
  end

  test "the sidebar has an Admin section linking to it" do
    get users_path

    assert_select "nav.sidebar h6", text: "Admin"
    assert_select "nav.sidebar a[href=?]", users_path, text: "Users"
  end

  # The route ordering has to keep Devise's own routes matching first.
  test "devise's sign-in route still resolves" do
    sign_out users(:admin)

    get new_user_session_path

    assert_response :success
  end
end
