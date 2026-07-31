require "test_helper"

class LearningSetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
    @set = LearningSet.create!(name: "Exhibitor lists", description: "Pages that name many orgs.")
  end

  test "index lists learning sets with their source counts" do
    @set.add_url("https://learning.test/a")

    get learning_sets_path

    assert_response :success
    assert_match "Exhibitor lists", @response.body
  end

  test "new and edit render the form" do
    get new_learning_set_path
    assert_response :success
    assert_select "input[name=?]", "learning_set[name]"

    get edit_learning_set_path(@set)
    assert_response :success
    assert_select "input[name=?][value=?]", "learning_set[name]", "Exhibitor lists"
  end

  test "create persists a learning set" do
    assert_difference "LearningSet.count", 1 do
      post learning_sets_path, params: {
        learning_set: { name: "News pages", description: "Acquisition coverage." }
      }
    end

    assert_redirected_to learning_set_path(LearningSet.find_by(name: "News pages"))
  end

  test "create without a name re-renders the form" do
    assert_no_difference "LearningSet.count" do
      post learning_sets_path, params: { learning_set: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "update changes the name" do
    patch learning_set_path(@set), params: { learning_set: { name: "Renamed" } }

    assert_equal "Renamed", @set.reload.name
  end

  test "show offers the add-by-url form and lists the sources" do
    @set.add_url("https://learning.test/exhibitors")

    get learning_set_path(@set)

    assert_response :success
    assert_select "form[action=?]", add_source_learning_set_path(@set)
    assert_match "https://learning.test/exhibitors", @response.body
  end

  test "adding a url creates the source and links it" do
    assert_difference [ "Source.count", "LearningSetSource.count" ], 1 do
      post add_source_learning_set_path(@set), params: { url: "https://learning.test/new" }
    end

    follow_redirect!
    assert_match(/Added/, @response.body)
  end

  test "adding a url the app already knows links the existing source" do
    existing = Source.create!(url: "https://learning.test/known")

    assert_no_difference "Source.count" do
      assert_difference "LearningSetSource.count", 1 do
        post add_source_learning_set_path(@set), params: { url: "https://learning.test/known" }
      end
    end

    assert_equal [ existing ], @set.reload.sources.to_a
  end

  test "adding a url already in the set is reported rather than duplicated" do
    @set.add_url("https://learning.test/known")

    assert_no_difference "LearningSetSource.count" do
      post add_source_learning_set_path(@set), params: { url: "https://learning.test/known" }
    end

    follow_redirect!
    assert_match(/already in/, @response.body)
  end

  test "adding junk reports the problem and saves nothing" do
    assert_no_difference [ "Source.count", "LearningSetSource.count" ] do
      post add_source_learning_set_path(@set), params: { url: "not a url" }
    end

    follow_redirect!
    assert_match(/not a usable URL/, @response.body)
  end

  test "removing a source keeps the source itself" do
    outcome = @set.add_url("https://learning.test/a")

    assert_difference "LearningSetSource.count", -1 do
      assert_no_difference "Source.count" do
        delete remove_source_learning_set_path(@set, source_id: outcome.source.id)
      end
    end

    follow_redirect!
    assert_match(/source itself was kept/, @response.body)
  end

  test "deleting a set keeps its sources" do
    @set.add_url("https://learning.test/a")

    assert_difference "LearningSet.count", -1 do
      assert_no_difference "Source.count" do
        delete learning_set_path(@set)
      end
    end

    assert_redirected_to learning_sets_path
  end

  test "the source page offers a learning set dropdown" do
    source = Source.create!(url: "https://learning.test/from-source")

    get source_path(source)

    assert_response :success
    assert_select "form[action=?]", add_to_learning_set_source_path(source)
    assert_select "select[name=?] option", "learning_set_id", text: "Exhibitor lists"
  end

  test "adding to a set from the source page returns to the source" do
    source = Source.create!(url: "https://learning.test/from-source")

    assert_difference "LearningSetSource.count", 1 do
      post add_to_learning_set_source_path(source), params: { learning_set_id: @set.id }
    end

    assert_redirected_to source_path(source)
    follow_redirect!
    assert_match(/Added/, @response.body)
    assert_match "Exhibitor lists", @response.body
  end

  test "adding from the source page without picking a set says so" do
    source = Source.create!(url: "https://learning.test/from-source")

    assert_no_difference "LearningSetSource.count" do
      post add_to_learning_set_source_path(source), params: { learning_set_id: "" }
    end

    follow_redirect!
    assert_match(/Select a learning set/, @response.body)
  end

  test "adding a source already in the set from its own page is a no-op" do
    source = Source.create!(url: "https://learning.test/from-source")
    @set.add_source(source)

    assert_no_difference "LearningSetSource.count" do
      post add_to_learning_set_source_path(source), params: { learning_set_id: @set.id }
    end

    follow_redirect!
    assert_match(/already in/, @response.body)
  end

  test "learning sets require authentication" do
    sign_out users(:admin)

    get learning_sets_path

    assert_redirected_to new_user_session_path
  end
end
