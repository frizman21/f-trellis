require "test_helper"
require "tmpdir"

class AppVersionTest < ActiveSupport::TestCase
  SHA = "0123456789abcdef0123456789abcdef01234567".freeze
  OTHER_SHA = "fedcba9876543210fedcba9876543210fedcba98".freeze

  setup do
    @original_git_rev = ENV["GIT_REV"]
    ENV.delete("GIT_REV")
  end

  teardown do
    if @original_git_rev.nil?
      ENV.delete("GIT_REV")
    else
      ENV["GIT_REV"] = @original_git_rev
    end
  end

  test "GIT_REV wins over the working tree" do
    ENV["GIT_REV"] = SHA

    with_git_dir(head: "ref: refs/heads/main", loose_refs: { "refs/heads/main" => OTHER_SHA }) do |git_dir|
      assert_equal SHA, AppVersion.sha(git_dir: git_dir)
    end
  end

  test "short is the first six characters of the sha" do
    ENV["GIT_REV"] = SHA

    assert_equal "012345", AppVersion.short
    assert_equal 6, AppVersion.short.length
  end

  test "a blank GIT_REV falls through to the git directory" do
    with_git_dir(head: "ref: refs/heads/main", loose_refs: { "refs/heads/main" => SHA }) do |git_dir|
      ENV["GIT_REV"] = "   "

      assert_equal SHA, AppVersion.sha(git_dir: git_dir)
    end
  end

  test "resolves a loose ref" do
    with_git_dir(head: "ref: refs/heads/main", loose_refs: { "refs/heads/main" => SHA }) do |git_dir|
      assert_equal SHA, AppVersion.sha(git_dir: git_dir)
    end
  end

  test "resolves a packed ref" do
    packed = <<~REFS
      # pack-refs with: peeled fully-peeled sorted
      #{OTHER_SHA} refs/heads/other
      #{SHA} refs/heads/main
    REFS

    with_git_dir(head: "ref: refs/heads/main", packed_refs: packed) do |git_dir|
      assert_equal SHA, AppVersion.sha(git_dir: git_dir)
    end
  end

  test "resolves a detached HEAD holding a raw sha" do
    with_git_dir(head: SHA) do |git_dir|
      assert_equal SHA, AppVersion.sha(git_dir: git_dir)
    end
  end

  test "returns nil when the git directory is missing" do
    Dir.mktmpdir do |dir|
      assert_nil AppVersion.sha(git_dir: File.join(dir, "nonexistent"))
      assert_nil AppVersion.short(git_dir: File.join(dir, "nonexistent"))
    end
  end

  test "returns nil when HEAD points at a ref that does not exist" do
    with_git_dir(head: "ref: refs/heads/main") do |git_dir|
      assert_nil AppVersion.sha(git_dir: git_dir)
    end
  end

  test "returns nil when HEAD holds something that is not a sha" do
    with_git_dir(head: "not a sha at all") do |git_dir|
      assert_nil AppVersion.sha(git_dir: git_dir)
    end
  end

  test "does not read outside the git directory" do
    with_git_dir(head: "ref: ../../../../etc/passwd") do |git_dir|
      assert_nil AppVersion.sha(git_dir: git_dir)
    end
  end

  test "commit_url points at the full sha on GitHub" do
    ENV["GIT_REV"] = SHA

    assert_equal "https://github.com/frizman21/f-dod/commit/#{SHA}", AppVersion.commit_url
  end

  test "commit_url is nil when the sha is unknown" do
    Dir.mktmpdir do |dir|
      assert_nil AppVersion.commit_url(git_dir: File.join(dir, "nonexistent"))
    end
  end

  private

  def with_git_dir(head:, loose_refs: {}, packed_refs: nil)
    Dir.mktmpdir do |dir|
      git_dir = File.join(dir, ".git")
      FileUtils.mkdir_p(git_dir)
      File.write(File.join(git_dir, "HEAD"), "#{head}\n")

      loose_refs.each do |ref, sha|
        path = File.join(git_dir, ref)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "#{sha}\n")
      end

      File.write(File.join(git_dir, "packed-refs"), packed_refs) if packed_refs

      yield git_dir
    end
  end
end
