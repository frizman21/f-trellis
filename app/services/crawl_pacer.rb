# Keeps a crawl from hitting one host faster than it agreed to.
#
# The clock and the sleeper are injected so tests can assert on pacing without
# actually waiting — a suite that really slept would take minutes, and the
# temptation would then be to stop testing it.
#
# Scope is one crawl. CrawlJob is a single synchronous traversal, so an
# in-memory map covers the whole of it. Two *concurrent* crawls of the same
# host will not pace against each other, which is reachable given
# config/queue.yml runs several threads. Fixing that needs a shared clock and a
# locking decision, and is deliberately left out rather than guessed at.
class CrawlPacer
  def initialize(clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
                 sleeper: ->(seconds) { Kernel.sleep(seconds) })
    @clock = clock
    @sleeper = sleeper
    @last_request_at = {}
  end

  # Waits only for whatever is left of the interval, then records the attempt.
  def wait_for(host, delay_seconds)
    key = host.to_s.downcase
    delay = delay_seconds.to_f

    if delay.positive?
      last = @last_request_at[key]
      remaining = last ? delay - (@clock.call - last) : 0
      @sleeper.call(remaining) if remaining.positive?
    end

    @last_request_at[key] = @clock.call
  end
end
