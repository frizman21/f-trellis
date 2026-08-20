require "test_helper"

# The structure page's counts say how many instances are deleted rather than
# leaving them out.
#
# A kept count alone is what made #66 invisible: the page reported "0
# relationships" while the delete refused because a discarded one still existed,
# and nothing on screen could account for the contradiction. Soft delete removed
# the refusal; this text removes the other half.
class DeletedInstanceCountsTest < ActionDispatch::IntegrationTest
  setup { @project = projects(:apollo) }

  def structure_row(type_name)
    get structure_project_path(@project)
    assert_response :success
    # The row for one type, as text, so the assertion is about what a reader sees
    # rather than about which cell it landed in.
    css_select("tr").map(&:text).find { |row| row.include?(type_name) }
  end

  test "a count with nothing deleted carries no parenthetical" do
    row = structure_row("Powers")

    assert_includes row, "1"
    assert_not_includes row, "deleted",
                        "the common row must not acquire noise to make the rare one legible"
  end

  test "a count says how many of the rows are deleted" do
    # Two more of the same kind, one of which is then removed: 3 rows, 2 kept.
    2.times do |i|
      Relationship.create!(project: @project, relationship_type: relationship_types(:powers),
                           from_entity: entities(:unnamed_engine), to_entity: entities(:saturn_v))
                  .tap { |r| r.discard! if i.zero? }
    end

    row = structure_row("Powers")

    assert_includes row, "2"
    assert_includes row, "(1 deleted)"
  end

  test "a count with everything deleted reads zero rather than blank" do
    relationships(:f1_powers_saturn_v).discard!

    row = structure_row("Powers")

    assert_includes row, "0"
    assert_includes row, "(1 deleted)"
  end

  test "entity counts say the same thing" do
    entities(:unnamed_engine).discard!

    row = structure_row("Rocket Engine")

    assert_includes row, "(1 deleted)"
  end
end
