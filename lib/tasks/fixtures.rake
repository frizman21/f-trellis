require "net/http"
require "uri"
require "json"
require "yaml"

namespace :fixtures do
  desc "Promote sources/skills marked is_promotable=true into local test/fixtures/*.yml. " \
       "HOST=http://localhost:3000 (default) or https://example.com for remote."
  task :promote do
    host = ENV.fetch("HOST", "http://localhost:3000")
    fixtures_dir = Rails.root.join("test", "fixtures")

    puts "[fixtures:promote] host=#{host}"

    index = fetch_index(host)
    sources = index.fetch("sources", [])
    skills  = index.fetch("skills",  [])

    if sources.empty? && skills.empty?
      puts "[fixtures:promote] nothing to promote (no records with is_promotable=true and is_fixtured=false)"
      next
    end

    if sources.any?
      write_fixture_file(fixtures_dir.join("sources.yml"), sources) { |s| source_fixture_entry(s) }
      sources.each { |s| flip_fixtured(host, "sources", s["id"]) }
      puts "[fixtures:promote] sources: promoted #{sources.size}"
    end

    if skills.any?
      write_fixture_file(fixtures_dir.join("skills.yml"), skills) { |s| skill_fixture_entry(s) }
      skill_revisions = skills.flat_map { |s| (s["revisions"] || []).map { |r| r.merge("skill_id" => s["id"]) } }
      if skill_revisions.any?
        write_fixture_file(fixtures_dir.join("skill_revisions.yml"), skill_revisions) { |r| skill_revision_fixture_entry(r) }
      end
      skills.each { |s| flip_fixtured(host, "skills", s["id"]) }
      puts "[fixtures:promote] skills: promoted #{skills.size} (#{skill_revisions.size} revisions)"
    end
  end
end

def fetch_index(host)
  uri = URI.join(host, "/fixture_promotions.json")
  res = Net::HTTP.get_response(uri)
  raise "GET #{uri} failed: #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)
  JSON.parse(res.body)
end

def flip_fixtured(host, resource, id)
  uri = URI.join(host, "/fixture_promotions/#{resource}/#{id}")
  req = Net::HTTP::Patch.new(uri)
  req["Content-Type"] = "application/json"
  req["Accept"] = "application/json"
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(req) }
  raise "PATCH #{uri} failed: #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)
end

# Merges new entries into an existing fixture YAML file, keyed by record id.
# Existing entries with matching keys are overwritten; others are preserved so
# manually-curated fixtures aren't lost.
def write_fixture_file(path, records, &entry_builder)
  existing = path.exist? ? (YAML.safe_load(path.read, permitted_classes: [Date, Time, Symbol]) || {}) : {}

  records.each do |record|
    key = "promoted_#{record['id']}"
    existing[key] = entry_builder.call(record)
  end

  path.write(<<~HEADER + existing.to_yaml.sub(/\A---\s*\n/, ""))
    # Read about fixtures at https://api.rubyonrails.org/classes/ActiveRecord/FixtureSet.html
    # Entries prefixed `promoted_<id>` are written by `rails fixtures:promote`.
  HEADER
end

def source_fixture_entry(s)
  {
    "url"           => s["url"],
    "description"   => s["description"],
    "status"        => s["status"],
    "is_promotable" => s["is_promotable"],
    "is_fixtured"   => true
  }
end

def skill_fixture_entry(s)
  {
    "name"          => s["name"],
    "purpose"       => s["purpose"],
    "is_active"     => s["is_active"],
    "is_promotable" => s["is_promotable"],
    "is_fixtured"   => true
  }
end

def skill_revision_fixture_entry(r)
  {
    "skill"    => "promoted_#{r['skill_id']}",
    "sequence" => r["sequence"],
    "content"  => r["content"]
  }
end
