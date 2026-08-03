# Which commit is currently running.
#
# Pushes to main reach production on their own — a poller deploys the newest
# green commit — so the question this answers is "has my change landed yet?"
# The answer has to come from the running process itself; anything derived from
# the repository on a developer's machine describes a different computer.
#
# In production it comes from ENV["GIT_REV"], the config var Dokku sets on every
# git-based deploy. That is the same value the auto-deploy poller compares
# against to decide whether to deploy at all (see docs/dokku_devops.md), so the
# page agrees with the deployer by construction. It is also the only source
# there is: .dockerignore excludes /.git/, so the image carries no repository.
#
# In development there is no GIT_REV and the checkout is mounted, so the .git
# directory answers instead. That path reads files rather than shelling out to
# `git` — no dependency on the binary being installed, and no subprocess on a
# request path.
class AppVersion
  SHORT_LENGTH = 6
  REPOSITORY_URL = "https://github.com/frizman21/f-dod".freeze

  class << self
    # Full commit SHA, or nil when it cannot be determined.
    def sha(git_dir: default_git_dir)
      from_env || from_git_dir(git_dir)
    end

    # First SHORT_LENGTH characters of the SHA, or nil.
    def short(git_dir: default_git_dir)
      sha(git_dir: git_dir)&.slice(0, SHORT_LENGTH)
    end

    # The commit on GitHub, or nil when the SHA is unknown.
    def commit_url(git_dir: default_git_dir)
      resolved = sha(git_dir: git_dir)
      return nil if resolved.nil?

      "#{REPOSITORY_URL}/commit/#{resolved}"
    end

    private

    def default_git_dir
      Rails.root.join(".git")
    end

    def from_env
      ENV["GIT_REV"].presence&.strip.presence
    end

    # HEAD is either a raw SHA (detached) or "ref: refs/heads/<branch>". A ref
    # lives in its own file until `git gc` packs it into packed-refs, so both
    # have to be tried.
    def from_git_dir(git_dir)
      head = read_file(git_dir, "HEAD")
      return nil if head.nil?

      ref = head[/\Aref:\s*(\S+)/, 1]
      return sha_or_nil(head) if ref.nil?

      sha_or_nil(read_file(git_dir, ref)) || packed_ref(git_dir, ref)
    end

    def packed_ref(git_dir, ref)
      packed = read_file(git_dir, "packed-refs")
      return nil if packed.nil?

      sha_or_nil(packed[/^([0-9a-f]{40})\s+#{Regexp.escape(ref)}$/, 1])
    end

    def read_file(git_dir, relative_path)
      path = File.expand_path(relative_path, git_dir)
      # Keeps a crafted HEAD from reaching outside the git directory.
      return nil unless path.start_with?(File.expand_path(git_dir).to_s + File::SEPARATOR)
      return nil unless File.file?(path)

      File.read(path).strip
    rescue SystemCallError, IOError
      nil
    end

    def sha_or_nil(value)
      value.to_s[/\A[0-9a-f]{40}\z/]
    end
  end
end
