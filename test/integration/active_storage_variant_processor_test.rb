require "test_helper"

# Active Storage names a variant processor in configuration, but the gem that
# actually implements it is a separate, optional dependency. Nothing in the
# ordinary suite forces that gem to load, so the two can drift apart silently:
# the app declares :vips, the backend is absent, and every test still passes
# until something requires it for real. That is exactly what happened on
# Rails 8.1.3.1, which loads the backend during boot (CVE-2026-66066) and so
# turned a dormant gap into `bin/rails aborted!`.
#
# These tests guard the seam between "processor declared" and "backend
# installed". They deliberately assert loadability and wiring only — not image
# transcoding, and not which formats 8.1.3.1 now blocks.
class ActiveStorageVariantProcessorTest < ActiveSupport::TestCase
  test "the configured variant processor is the one the backend is installed for" do
    assert_equal :vips, ActiveStorage.variant_processor
  end

  test "the vips backend is installed and loadable" do
    assert_nothing_raised do
      require "image_processing/vips"
    end

    assert defined?(ImageProcessing::Vips),
      "ImageProcessing::Vips is not defined — the ruby-vips gem is missing from the bundle"
  end

  test "libvips itself is present and new enough for Rails' floor" do
    require "image_processing/vips"

    # Rails 8.1.3.1 raised the minimum supported libvips to 8.13. The gem
    # linking is not enough on its own: the shared library has to be there too,
    # which is a system-package concern and differs per environment (dev
    # container, CI, production image).
    assert_operator Gem::Version.new(Vips.version_string), :>=, Gem::Version.new("8.13"),
      "libvips is older than the 8.13 minimum Rails 8.1.3.1 requires"
  end
end
