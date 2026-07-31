require "test_helper"

class LearningSetTest < ActiveSupport::TestCase
  setup do
    @set = LearningSet.create!(name: "Exhibitor lists")
  end

  test "a learning set requires a name" do
    blank = LearningSet.new

    assert_not blank.valid?
    assert_includes blank.errors[:name], "can't be blank"
  end

  test "two learning sets cannot share a name" do
    duplicate = LearningSet.new(name: "exhibitor lists")

    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :name
  end

  test "adding a new url creates one source and links it" do
    outcome = nil

    assert_difference "Source.count", 1 do
      outcome = @set.add_url("https://learning.test/exhibitors")
    end

    assert outcome.added?
    assert_equal [ "https://learning.test/exhibitors" ], @set.reload.sources.map(&:url)
    assert_match(/Added/, outcome.message)
  end

  test "a url the app already knows is linked, not duplicated" do
    existing = Source.create!(url: "https://learning.test/exhibitors")

    outcome = nil
    assert_no_difference "Source.count" do
      outcome = @set.add_url("https://learning.test/exhibitors")
    end

    assert outcome.added?
    assert_equal existing, outcome.source
  end

  test "adding the same url twice changes nothing and says so" do
    @set.add_url("https://learning.test/exhibitors")

    outcome = nil
    assert_no_difference [ "Source.count", "LearningSetSource.count" ] do
      outcome = @set.add_url("https://learning.test/exhibitors")
    end

    assert outcome.already_member?
    assert_match(/already in Exhibitor lists/, outcome.message)
  end

  test "a fragment names a spot on a page, not another page" do
    @set.add_url("https://learning.test/exhibitors")

    outcome = nil
    assert_no_difference "Source.count" do
      outcome = @set.add_url("https://learning.test/exhibitors#hall-b")
    end

    assert outcome.already_member?
  end

  test "surrounding space and a missing scheme are tolerated" do
    outcome = @set.add_url("  learning.test/exhibitors  ")

    assert outcome.added?
    assert_equal "https://learning.test/exhibitors", outcome.source.url
  end

  test "text that is not a url is rejected rather than saved" do
    outcome = nil

    assert_no_difference [ "Source.count", "LearningSetSource.count" ] do
      outcome = @set.add_url("not a url at all")
    end

    assert outcome.invalid?
    assert_match(/not a usable URL/, outcome.message)
  end

  test "a blank url is rejected" do
    assert @set.add_url("").invalid?
    assert @set.add_url(nil).invalid?
  end

  test "a source cannot be joined to the same set twice" do
    source = Source.create!(url: "https://learning.test/a")
    @set.add_source(source)

    duplicate = LearningSetSource.new(learning_set: @set, source: source)

    assert_not duplicate.valid?
  end

  test "the same source can belong to more than one set" do
    source = Source.create!(url: "https://learning.test/a")
    other = LearningSet.create!(name: "News pages")

    @set.add_source(source)
    other.add_source(source)

    assert_equal [ "Exhibitor lists", "News pages" ], source.learning_sets.order(:name).map(&:name)
  end

  test "destroying a set drops its memberships but keeps the sources" do
    @set.add_url("https://learning.test/a")

    assert_difference "LearningSetSource.count", -1 do
      assert_no_difference "Source.count" do
        @set.destroy!
      end
    end
  end

  test "destroying a source drops it from its sets" do
    outcome = @set.add_url("https://learning.test/a")

    assert_difference "LearningSetSource.count", -1 do
      outcome.source.destroy!
    end
  end
end
