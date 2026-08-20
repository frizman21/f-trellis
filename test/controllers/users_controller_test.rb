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

  # Rendered beside the read-only marker rather than instead of it, because an
  # account can be both.
  test "index marks admin accounts" do
    get users_path

    assert_select "tbody tr" do |rows|
      admin = rows.detect { |r| r.text.include?(users(:admin).email) }
      assert_match(/admin/, admin.text)

      plain = rows.detect { |r| r.text.include?(users(:other).email) }
      assert_no_match(/admin/, plain.text)
      assert_match(/full/, plain.text)
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

  # In the navbar beside the running commit, so it is reachable from every page
  # rather than only from those that render a sidebar.
  test "the navbar links an admin to the data admin" do
    get users_path

    assert_select "nav.navbar a[href=?]", admin_root_path do |links|
      assert_equal "Data Admin", links.first["aria-label"],
                   "the icon is the whole link, so it needs a name of its own"
      assert_select "svg"
    end
  end

  # /admin 404s for a non-admin, so a link to it would be a door that reports
  # itself missing.
  test "the navbar omits the data admin link for a non-admin" do
    sign_out users(:admin)
    sign_in users(:other)

    get users_path

    assert_response :success
    assert_select "a[href=?]", admin_root_path, count: 0
  end

  # The sidebar is absent on full-width pages, which is why the link is not
  # there; nothing should have put it back.
  test "the data admin link is reachable from a page with no sidebar" do
    get projects_path

    assert_select "nav.sidebar", count: 0
    assert_select "nav.navbar a[href=?]", admin_root_path, count: 1
  end

  # The route ordering has to keep Devise's own routes matching first.
  test "devise's sign-in route still resolves" do
    sign_out users(:admin)

    get new_user_session_path

    assert_response :success
  end
end
