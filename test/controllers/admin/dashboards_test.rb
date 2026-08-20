require "test_helper"

# Administrate resolves a dashboard's attributes against the model at request
# time, so a column renamed or dropped by a migration turns into a 500 on that
# one resource's pages and nowhere else. Walking every dashboard here is what
# turns that into a failing test at the time of the migration.
class Admin::DashboardsTest < ActiveSupport::TestCase
  RESOURCES = Administrate::Namespace.new(:admin).resources.freeze

  # Everything below is a per-resource loop, so an empty list would make all of
  # them pass while asserting nothing.
  test "the admin namespace routes resources" do
    assert_not_empty RESOURCES
  end

  test "there is a dashboard for every routed admin resource" do
    RESOURCES.each do |resource|
      dashboard = begin
        resolver_for(resource).dashboard_class
      rescue NameError
        nil
      end

      assert dashboard, "#{resource.path} is routed under /admin with no dashboard"
    end
  end

  # Every name in ATTRIBUTE_TYPES has to be something the model answers to — a
  # column, an association, or a method — or the show and form pages raise.
  test "every dashboard attribute exists on its model" do
    RESOURCES.each do |resource|
      resolver = resolver_for(resource)
      record   = resolver.resource_class.new

      resolver.dashboard_class.new.all_attributes.each do |attribute|
        assert record.respond_to?(attribute),
               "#{resolver.dashboard_class} lists #{attribute}, " \
               "which #{resolver.resource_class} does not respond to"
      end
    end
  end

  # The three page lists are looked up in ATTRIBUTE_TYPES when the page renders;
  # a name in one of them that is not a key there fails there and only there.
  test "every page attribute is a declared attribute type" do
    RESOURCES.each do |resource|
      dashboard = resolver_for(resource).dashboard_class
      declared  = dashboard::ATTRIBUTE_TYPES.keys

      %i[COLLECTION_ATTRIBUTES SHOW_PAGE_ATTRIBUTES FORM_ATTRIBUTES].each do |list|
        assert_empty dashboard.const_get(list) - declared,
                     "#{dashboard}::#{list} names attributes missing from ATTRIBUTE_TYPES"
      end
    end
  end

  # Regenerating UserDashboard would put these back on all three pages, and the
  # damage is silent: a digest on a list view, a live reset token beside it, and
  # a form field that writes plaintext into the digest column.
  test "the user dashboard shows no credential columns" do
    hidden = %i[encrypted_password reset_password_token]

    %i[COLLECTION_ATTRIBUTES SHOW_PAGE_ATTRIBUTES FORM_ATTRIBUTES].each do |list|
      assert_empty UserDashboard.const_get(list) & hidden,
                   "UserDashboard::#{list} exposes a credential column"
    end
  end

  private

  # The same resolution Administrate's controllers do, from the routed path.
  def resolver_for(resource)
    Administrate::ResourceResolver.new("admin/#{resource.path}")
  end
end
