# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"

# Shared plumbing for the extraction proof of concept: where each stage's files
# live, what number a source carries through the pipeline, and the ledger that
# records what each stage did to it.
#
# The numbering is the point of this file. A source is numbered once, by its
# position in the URL list, and carries that number through every stage:
# 000-fetched.html becomes 000-stripped.txt becomes 000-extracted.json. Nothing
# downstream has to parse a URL, slugify a title, or guess which output belongs
# to which input — the filename says so. When a score looks wrong, the number is
# the thread back to the HTML it came from.
#
# The ledger (manifest.json) is what makes that thread auditable rather than
# merely conventional: each stage appends what it did, so a missing file and a
# file that was never produced are distinguishable after the fact.
module Poc
  ROOT = File.expand_path("..", __dir__)

  # Each stage owns a numbered directory, in the order the pipeline runs them.
  # The prefix is what makes `ls work/` read as the pipeline itself.
  STAGES = {
    input: "00-input",
    fetched: "01-fetched",
    stripped: "02-stripped",
    extracted: "03-extracted",
    validated: "04-validated",
    scored: "05-scored"
  }.freeze

  # What each stage's file for source NNN is called. One uniform NNN-<stage>.<ext>
  # scheme so a number can be grepped across every stage at once.
  FILENAMES = {
    fetched: "%<n>s-fetched.html",
    stripped: "%<n>s-stripped.txt",
    extracted: "%<n>s-extracted.json",
    raw: "%<n>s-raw.txt",
    validated: "%<n>s-validation.json",
    scored: "%<n>s-score.json",
    golden: "%<n>s-golden.json"
  }.freeze

  # Ground truth is reference data, not a pipeline stage — it is not produced by
  # a run and is not thrown away when one is re-run. It sits outside the numbered
  # directories for that reason, and keeps the same NNN so it still lines up.
  GOLDEN_DIR = "golden"

  MANIFEST = "manifest.json"

  class Error < StandardError; end

  module_function

  # Everything generated lives under one directory so a run can be thrown away
  # by deleting it. Overridable so two model bake-offs can run side by side
  # without sharing a ledger.
  def work
    @work ||= File.expand_path(ENV.fetch("POC_WORK", File.join(ROOT, "work")))
  end

  def work=(path)
    @work = File.expand_path(path)
  end

  def stage_dir(stage, run: nil)
    name = STAGES.fetch(stage) { raise Error, "unknown stage: #{stage}" }
    # The per-model stages nest one level deeper. Two models must not overwrite
    # each other's answers to the same source — that comparison is the reason
    # this pipeline exists.
    run ? File.join(work, name, run) : File.join(work, name)
  end

  def golden_dir = File.join(work, GOLDEN_DIR)

  def path_for(stage, number, run: nil, kind: nil)
    kind ||= stage
    File.join(stage_dir(stage, run: run), format(FILENAMES.fetch(kind), n: number))
  end

  def golden_path(number) = File.join(golden_dir, format(FILENAMES[:golden], n: number))

  def input_path(name) = File.join(stage_dir(:input), name)

  def urls_file        = input_path("urls.txt")
  def mental_model_file = input_path("mental-model.json")
  def instructions_file = input_path("instructions.md")

  def mkdir(path)
    FileUtils.mkdir_p(path)
    path
  end

  # A label safe to use as a directory name. Model ids carry dots, slashes and
  # colons depending on the provider, and any of the three would either nest or
  # break the run directory.
  def slug(text)
    text.to_s.strip.downcase.gsub(/[^a-z0-9._-]+/, "-").gsub(/-{2,}/, "-").gsub(/\A-|-\z/, "")
  end

  def number(index) = format("%03d", index)

  def sha(text) = Digest::SHA256.hexdigest(text.to_s)

  def read_json(path)
    JSON.parse(File.read(path))
  rescue JSON::ParserError => e
    raise Error, "#{path} is not valid JSON: #{e.message}"
  end

  def write_json(path, data)
    mkdir(File.dirname(path))
    File.write(path, "#{JSON.pretty_generate(data)}\n")
    path
  end

  # The URL list, with blank lines and # comments ignored. Position in this file
  # — counting only the URLs — is what assigns a source its number, so comments
  # can be added freely without renumbering anything.
  def urls
    raise Error, "no URL list at #{urls_file} — run bin/export-model first" unless File.exist?(urls_file)

    File.readlines(urls_file, chomp: true)
        .map { |line| line.sub(/\s+#.*\z/, "").strip }
        .reject { |line| line.empty? || line.start_with?("#") }
  end

  # The ledger. One entry per numbered source, each carrying the URL it was
  # numbered for and a record from every stage that has touched it.
  #
  # Loaded and saved whole rather than appended to: the file is small, the
  # scripts are sequential, and a JSON document that is always complete is one
  # that can be read while a run is half finished.
  class Manifest
    def self.open(...) = new(...)

    def initialize(path: File.join(Poc.work, Poc::MANIFEST))
      @path = path
      @data = File.exist?(path) ? Poc.read_json(path) : { "version" => 1, "items" => {} }
      @data["items"] ||= {}
    end

    attr_reader :path, :data

    def items = @data["items"]

    def entry(number) = items[number]

    def numbers = items.keys.sort

    def url_for(number) = items.dig(number, "url")

    # Assign a number to every URL in the list, in order.
    #
    # A number that already names a different URL is a hard error rather than a
    # silent reassignment. Inserting a line at the top of urls.txt would
    # otherwise shift every number by one, and every golden file, score and
    # fetched page would quietly start describing a different page than the one
    # it was written for. That is precisely the failure this numbering exists to
    # prevent, so it fails loudly and says how to proceed.
    def sync!(urls, renumber: false)
      urls.each_with_index do |url, index|
        n = Poc.number(index)
        existing = items[n]

        if existing && existing["url"] != url && !renumber
          raise Poc::Error, <<~MSG.strip
            #{n} was numbered for #{existing["url"]}
            but urls.txt now has #{url} at that position.

            Renumbering invalidates every downstream file carrying #{n} —
            fetched HTML, stripped text, extractions, goldens and scores.
            Append new URLs to the end of urls.txt instead, or re-run with
            --renumber and clear the work directory.
          MSG
        end

        items[n] = (existing || {}).merge("url" => url, "url_sha" => Poc.sha(url), "n" => n)
      end

      # A URL removed from the list keeps its entry and its number. The files it
      # produced are still on disk and still worth tracing; dropping the entry
      # would orphan them and free the number for something else.
      items.each_value { |item| item["retired"] = true unless urls.include?(item["url"]) }

      self
    end

    def record(number, stage, data)
      items[number] ||= { "n" => number }
      (items[number]["stages"] ||= {})[stage.to_s] = data
      self
    end

    # A per-model stage records under the run label so two models' results sit
    # side by side in the ledger the way they do on disk.
    def record_run(number, stage, run, data)
      items[number] ||= { "n" => number }
      stages = (items[number]["stages"] ||= {})
      (stages[stage.to_s] ||= {})[run] = data
      self
    end

    def stage_record(number, stage, run: nil)
      record = items.dig(number, "stages", stage.to_s)
      run ? record&.dig(run) : record
    end

    def save
      Poc.write_json(@path, @data)
      self
    end
  end
end
