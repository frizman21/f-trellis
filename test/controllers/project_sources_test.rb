require "test_helper"

# The sources a project cares about. The crawling side knows nothing about
# projects: a source is a page on the internet, and the join is what makes one a
# given project's concern.
class ProjectSourcesTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    @other = projects(:gemini)
  end

  def add(url, description: nil)
    post project_sources_path(@project),
         params: { source: { url: url, description: description } }
  end

  # --- the index -------------------------------------------------------------

  test "index lists only this project's sources" do
    ProjectSource.create!(project: @project, source: sources(:one))
    ProjectSource.create!(project: @other, source: sources(:two))

    get project_sources_path(@project)

    assert_response :success
    # Linked within the project rather than out to the global page.
    assert_select "a[href=?]", project_source_path(@project, sources(:one))
    assert_select "a[href=?]", project_source_path(@project, sources(:two)), count: 0
    assert_select "a[href=?]", source_path(sources(:one)), count: 0
  end

  test "index shows the empty state when the project has no sources" do
    get project_sources_path(@project)

    assert_response :success
    assert_match(/No sources on this project yet/, response.body)
  end

  # --- adding ----------------------------------------------------------------

  test "adding a new url creates the source, joins it, and queues its fetch" do
    assert_difference [ -> { Source.count }, -> { ProjectSource.count } ], 1 do
      assert_enqueued_with(job: FetchSourceJob) do
        add "https://example.com/brand-new-page"
      end
    end

    assert_redirected_to project_sources_path(@project)
    assert_includes @project.reload.sources.map(&:url), "https://example.com/brand-new-page"
  end

  # The specific failure this design avoids: a second row for one URL splits the
  # page's fetched content and its processing history in half.
  test "adding a url the crawler already has joins it rather than duplicating it" do
    existing = sources(:one)

    assert_no_difference -> { Source.count } do
      assert_difference -> { ProjectSource.count }, 1 do
        add existing.url
      end
    end

    assert_includes @project.reload.sources, existing
  end

  test "adding the same url twice does not duplicate the join" do
    add sources(:one).url

    assert_no_difference [ -> { Source.count }, -> { ProjectSource.count } ] do
      add sources(:one).url
    end

    assert_match(/already on this project/, flash[:notice])
  end

  test "one source can belong to two projects at once" do
    ProjectSource.create!(project: @other, source: sources(:one))

    assert_difference -> { ProjectSource.count }, 1 do
      add sources(:one).url
    end

    assert_includes @project.reload.sources, sources(:one)
    assert_includes @other.reload.sources, sources(:one)
  end

  test "an unusable url creates nothing and says why" do
    assert_no_difference [ -> { Source.count }, -> { ProjectSource.count } ] do
      add "not a url at all"
    end

    assert_response :unprocessable_entity
  end

  test "a description is kept when the page has none and never overwrites one" do
    add "https://example.com/undescribed", description: "Why this matters"

    assert_equal "Why this matters", Source.find_by(url: "https://example.com/undescribed").description

    before = sources(:one).description
    add sources(:one).url, description: "A different note"

    assert_equal before, sources(:one).reload.description
  end

  # --- removing --------------------------------------------------------------

  test "removing takes the join and leaves the page" do
    ProjectSource.create!(project: @project, source: sources(:one))

    assert_no_difference -> { Source.count } do
      assert_difference -> { ProjectSource.count }, -1 do
        delete project_source_path(@project, sources(:one))
      end
    end

    assert Source.exists?(sources(:one).id)
    assert_not_includes @project.reload.sources, sources(:one)
  end

  test "removing from one project leaves another project's join alone" do
    ProjectSource.create!(project: @project, source: sources(:one))
    ProjectSource.create!(project: @other, source: sources(:one))

    delete project_source_path(@project, sources(:one))

    assert_includes @other.reload.sources, sources(:one)
  end

  test "a source not on this project cannot be removed through it" do
    ProjectSource.create!(project: @other, source: sources(:one))

    delete project_source_path(@project, sources(:one))

    assert_response :not_found
    assert_includes @other.reload.sources, sources(:one)
  end

  # --- the crawling side is untouched ----------------------------------------

  test "destroying a project takes its joins and leaves the sources" do
    ProjectSource.create!(project: @project, source: sources(:one))

    assert_no_difference -> { Source.count } do
      assert_difference -> { ProjectSource.count }, -1 do
        @project.destroy
      end
    end
  end

  test "the global sources index still shows every source" do
    ProjectSource.create!(project: @other, source: sources(:two))

    get sources_path

    assert_response :success
    assert_select "a[href=?]", source_path(sources(:one))
    assert_select "a[href=?]", source_path(sources(:two))
  end

  # Routing order: the entity-type catch-all would otherwise swallow this.
  test "the project sources path is not taken for an entity type slug" do
    get project_sources_path(@project)

    assert_response :success
    assert_select "h1", "Sources"
  end

  test "an entity type named Source is rejected rather than shadowing the route" do
    type = @project.entity_types.new(name: "Source")

    assert_equal "sources", type.slug
    assert_not type.valid?
    assert_match(/reserved/, type.errors.full_messages.to_sentence)
  end

  # --- the project's own page for a source -----------------------------------

  test "a source's page renders inside the project" do
    ProjectSource.create!(project: @project, source: sources(:one))

    get project_source_path(@project, sources(:one))

    assert_response :success
    assert_select "a[href=?]", project_sources_path(@project)
    # One click further on for the crawler's own screen.
    assert_select "a[href=?]", source_path(sources(:one))
  end

  # Otherwise a guessed id quietly walks you out of the project you were in.
  test "a source another project holds is not found here" do
    ProjectSource.create!(project: @other, source: sources(:two))

    get project_source_path(@project, sources(:two))

    assert_response :not_found
  end

  test "the page says when a source is on other projects too" do
    ProjectSource.create!(project: @project, source: sources(:one))
    ProjectSource.create!(project: @other, source: sources(:one))

    get project_source_path(@project, sources(:one))

    assert_match(/Also on/, response.body)
    assert_match(/#{@other.name}/, response.body)
  end
end
