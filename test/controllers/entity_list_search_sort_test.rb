require "test_helper"

# Search and sort on a type's entity list. Both live in the query string, so a
# filtered, ordered list is a link.
class EntityListSearchSortTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    @type = entity_types(:rocket_engine)
    @path = project_typed_entities_path(@project, @type.slug)

    # A second and third engine, so ordering has something to order.
    @merlin = build_engine(name: "Merlin", chambers: 1, thrust_kn: 845.0, first_flight: "2006-03-24")
    @rs25   = build_engine(name: "RS-25", chambers: 3, thrust_kn: 1860.0, first_flight: "1981-04-12")
    # Nothing recorded at all: the null case for every sort.
    @blank = @project.entities.create!(entity_type: @type)
  end

  def build_engine(values)
    entity = @project.entities.create!(entity_type: @type)
    values.each do |name, raw|
      attribute = @type.entity_type_attributes.find_by!(name: name.to_s)
      record = entity.entity_attribute_values.build(entity_type_attribute: attribute)
      record.value = raw
      record.save!
    end
    entity
  end

  def labels
    css_select("tbody tr td:first-child").map { |td| td.text.strip }
  end

  # --- search ----------------------------------------------------------------

  test "search matches a string value" do
    get @path, params: { q: "Merlin" }

    assert_response :success
    assert_equal [ "Merlin" ], labels
  end

  test "search is case-insensitive" do
    get @path, params: { q: "mErLiN" }

    assert_equal [ "Merlin" ], labels
  end

  test "search matches a substring" do
    get @path, params: { q: "ocketdyne" }

    assert_equal [ "Rocketdyne F-1" ], labels
  end

  # A join would return this entity once per matching value; an IN returns it once.
  test "an entity matching on two attributes appears once" do
    two_ways = build_engine(name: "Vulcan", chambers: 2)
    other = @type.entity_type_attributes.find_by!(name: "name")
    assert other

    get @path, params: { q: "Vulcan" }

    assert_equal [ "Vulcan" ], labels
    assert_equal 1, labels.count("Vulcan")
    assert two_ways.persisted?
  end

  # The documented boundary, not an accident: numbers are sorted, not searched.
  test "search does not match numeric values" do
    get @path, params: { q: "845" }

    assert_empty labels
    assert_match(/match/, response.body)
  end

  test "a blank search returns everything" do
    get @path, params: { q: "" }

    assert_equal @project.entities.where(entity_type: @type).count, labels.size
  end

  # --- sorting ---------------------------------------------------------------

  # Relative order of two unambiguous names rather than comparing against Ruby's
  # sort: Postgres orders by its collation, Ruby by bytes, and the two disagree
  # on mixed case. What matters is that the database reverses when asked.
  test "sorting by a string attribute is alphabetical, both ways" do
    get @path, params: { sort: "name", dir: "asc" }
    ascending = labels.select { |l| [ "Merlin", "RS-25" ].include?(l) }

    get @path, params: { sort: "name", dir: "desc" }
    descending = labels.select { |l| [ "Merlin", "RS-25" ].include?(l) }

    assert_equal [ "Merlin", "RS-25" ], ascending
    assert_equal ascending.reverse, descending
  end

  test "sorting by an int attribute orders numerically, both ways" do
    get @path, params: { sort: "chambers", dir: "asc" }
    assert_equal [ "Merlin", "RS-25" ], labels.select { |l| %w[Merlin RS-25].include?(l) }

    get @path, params: { sort: "chambers", dir: "desc" }
    assert_equal [ "RS-25", "Merlin" ], labels.select { |l| %w[Merlin RS-25].include?(l) }
  end

  test "sorting by a float attribute orders numerically, both ways" do
    get @path, params: { sort: "thrust_kn", dir: "asc" }
    assert_equal [ "Merlin", "RS-25", "Rocketdyne F-1" ],
                 labels.select { |l| [ "Merlin", "RS-25", "Rocketdyne F-1" ].include?(l) }

    get @path, params: { sort: "thrust_kn", dir: "desc" }
    assert_equal [ "Rocketdyne F-1", "RS-25", "Merlin" ],
                 labels.select { |l| [ "Merlin", "RS-25", "Rocketdyne F-1" ].include?(l) }
  end

  test "sorting by a datetime attribute orders chronologically, both ways" do
    get @path, params: { sort: "first_flight", dir: "asc" }
    assert_equal [ "RS-25", "Merlin" ], labels.select { |l| %w[Merlin RS-25].include?(l) }

    get @path, params: { sort: "first_flight", dir: "desc" }
    assert_equal [ "Merlin", "RS-25" ], labels.select { |l| %w[Merlin RS-25].include?(l) }
  end

  # Otherwise they bunch at whichever end nulls happen to fall, which changes
  # with the direction and looks like the sort is wrong.
  test "entities with no value sort last in both directions" do
    blank_label = @blank.label

    get @path, params: { sort: "chambers", dir: "asc" }
    assert_equal blank_label, labels.last

    get @path, params: { sort: "chambers", dir: "desc" }
    assert_equal blank_label, labels.last
  end

  # --- the headers -----------------------------------------------------------

  test "every attribute header is a sort link" do
    get @path

    @type.entity_type_attributes.each do |attribute|
      assert_select "th a", text: /#{Regexp.escape(attribute.name)}/
    end
  end

  test "the header toggles direction and marks the current sort" do
    get @path, params: { sort: "chambers", dir: "asc" }

    assert_select "th a.fw-bold", text: /chambers ↑/
    assert_select "th a[href*=?]", "dir=desc"
  end

  # --- falling back ----------------------------------------------------------

  test "an unknown sort falls back rather than erroring" do
    get @path, params: { sort: "no-such-attribute" }

    assert_response :success
  end

  test "another type's attribute is ignored" do
    get @path, params: { sort: entity_type_attributes(:vehicle_stages).name }

    assert_response :success
  end

  test "a bad direction falls back to ascending" do
    get @path, params: { sort: "chambers", dir: "sideways" }

    assert_response :success
    assert_select "th a.fw-bold", text: /chambers ↑/
  end

  # --- together --------------------------------------------------------------

  test "search and sort compose" do
    # "RS" rather than "R": search is case-insensitive, so "R" also matches the
    # r in Merlin.
    get @path, params: { q: "S-", sort: "thrust_kn", dir: "desc" }

    assert_response :success
    assert_equal [ "RS-25" ], labels
  end

  test "the search form keeps the current sort" do
    get @path, params: { sort: "chambers", dir: "desc" }

    assert_select "form[action*=?]", "sort=chambers"
  end
end
