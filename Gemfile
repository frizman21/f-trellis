source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 2.0"

# image_processing 2.0 dropped ruby-vips from its runtime dependencies, so the
# application has to declare the backend for the :vips processor Active Storage
# defaults to. Not optional in practice: Rails 8.1.3.1 calls
# Vips.block_untrusted(true) during boot (CVE-2026-66066), which loads this gem
# before any variant is ever requested — without it, `rails` aborts at boot.
# The 2.2.1 floor is that release's stated new minimum.
gem "ruby-vips", "~> 2.2", ">= 2.2.1"

# Zip archive creation for storing fetched source content as SourceDatum payloads.
gem "rubyzip", "~> 3.4"

# Text extraction from fetched PDFs. Pure Ruby on purpose: shelling out to
# pdftotext extracts better text on awkward layouts, but poppler is not in the
# runtime image, and running a spawned binary over attacker-supplied bytes in a
# background job is a worse trade than the quality delta is worth.
gem "pdf-reader", "~> 2.14"

# Pagination for index views.
gem "kaminari"

# Soft delete for entities and relationships. discard rather than paranoia:
# paranoia overrides destroy so that a method whose name says "delete" does not,
# which makes every call site ambiguous. discard adds discard/undiscard and
# leaves destroy meaning what it says.
gem "discard", "~> 1.4"

# Random name/company/job generators for synthetic seed data.
gem "faker"

# Unified Ruby interface to LLM providers (OpenAI, Anthropic, Gemini, etc.).
gem "ruby_llm"

# Authentication.
gem "devise"

# Generated CRUD back office at /admin, for reading and correcting rows no
# screen in this application exposes. administrate rather than rails_admin,
# activeadmin or avo because of this deployment rather than a feature
# comparison: the container has no node/yarn and the pipeline is propshaft +
# importmap, so rails_admin's importmap path (which shells out to `yarn add`)
# and activeadmin's sprockets/sassc assumptions are both unavailable.
# administrate ships pre-built CSS and JS in its own app/assets/builds and adds
# no transitive dependency this Gemfile does not already carry — its only
# runtime deps are actionpack/actionview/activerecord and kaminari.
gem "administrate", "~> 1.0"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Auto-restart the Rails server when Gemfile.lock or db/schema.rb changes,
  # so newly installed gems and new tables don't require a manual container
  # restart. See docker-compose.yml `web.command`.
  gem "rerun"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
