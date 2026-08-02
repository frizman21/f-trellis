require "test_helper"

class SourceExclusionsControllerTest < ActionDispatch::IntegrationTest
  test "index renders" do
    SourceExclusion.create!(pattern: "https://news.ycombinator.com/item?id=*",
                            description: "Comment threads.")

    get source_exclusions_path

    assert_response :success
    assert_match(/news\.ycombinator\.com/, response.body)
    assert_match(/Comment threads/, response.body)
  end

  test "index renders with no exclusions" do
    SourceExclusion.delete_all

    get source_exclusions_path

    assert_response :success
    assert_match(/No exclusions yet/, response.body)
  end

  test "index shows how many existing sources a pattern covers" do
    SourceExclusion.create!(pattern: "https://example.com/*")

    get source_exclusions_path

    assert_response :success
    assert_select "td.text-end", text: /\d/
  end

  test "new renders" do
    get new_source_exclusion_path

    assert_response :success
  end

  test "create persists a valid pattern" do
    assert_difference -> { SourceExclusion.count }, +1 do
      post source_exclusions_path, params: {
        source_exclusion: {
          pattern: "news.ycombinator.com/item?id=*",
          description: "Comment threads.",
          is_enabled: "1"
        }
      }
    end

    assert_redirected_to source_exclusions_path
    assert_equal "https://news.ycombinator.com/item?id=*", SourceExclusion.last.pattern
  end

  test "create rejects a pattern that is not a URL" do
    assert_no_difference -> { SourceExclusion.count } do
      post source_exclusions_path, params: { source_exclusion: { pattern: "not a url" } }
    end

    assert_response :unprocessable_entity
    assert_match(/must be a URL/, response.body)
  end

  test "edit renders" do
    exclusion = SourceExclusion.create!(pattern: "https://example.com/a/*")

    get edit_source_exclusion_path(exclusion)

    assert_response :success
  end

  test "update changes the pattern" do
    exclusion = SourceExclusion.create!(pattern: "https://example.com/a/*")

    patch source_exclusion_path(exclusion), params: {
      source_exclusion: { pattern: "https://example.com/b/*", is_enabled: "0" }
    }

    assert_redirected_to source_exclusions_path
    exclusion.reload
    assert_equal "https://example.com/b/*", exclusion.pattern
    assert_not exclusion.is_enabled
  end

  test "destroy removes the exclusion" do
    exclusion = SourceExclusion.create!(pattern: "https://example.com/gone/*")

    assert_difference -> { SourceExclusion.count }, -1 do
      delete source_exclusion_path(exclusion)
    end

    assert_redirected_to source_exclusions_path
  end
end
