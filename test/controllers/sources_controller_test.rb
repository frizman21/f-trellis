require "test_helper"

class SourcesControllerTest < ActionDispatch::IntegrationTest
  test "index renders and paginates without raising NoMethodError" do
    get sources_path
    assert_response :success
  end

  test "relation responds to #page (Kaminari wired in)" do
    assert Source.all.respond_to?(:page),
      "expected ActiveRecord::Relation to respond to #page — is kaminari loaded?"
  end
end
