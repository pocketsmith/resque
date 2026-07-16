require 'digest/md5'

module Resque
  # Measures queue latency — the time a job spends waiting between enqueue
  # and dequeue — without touching the job payload. Plugins derive uniqueness
  # keys and digests from the payload (resque-loner, resque-workers-lock), so
  # it must stay byte-identical; instead, enqueue timestamps live in a
  # companion Redis list keyed by a digest of the raw encoded payload string.
  # push writes that exact string and pop reads it back, so the digest links
  # the two ends deterministically.
  #
  # Duplicate payloads are handled by the list: Resque queues are FIFO, so
  # the Nth push of a payload pairs with its Nth pop, and RPUSH/LPOP on the
  # companion list pairs timestamps the same way.
  #
  # Results accumulate as latency_ms:<queue> / latency_count:<queue> stat
  # counters (rate(sum)/rate(count) = average wait). Pops with no companion
  # entry (e.g. enqueued by code without this module during a rolling
  # deploy) count as latency_unmatched:<queue>; deltas outside sane bounds
  # (crash orphans mispairing) count as latency_discarded:<queue>.
  module Latency
    KEY_PREFIX = "latency_pending".freeze

    # Companion entries for jobs that never pop (removed queues, crashed
    # tracking) self-clean via TTL.
    PENDING_TTL = 24 * 60 * 60

    # A delta beyond this is a mispaired orphan, not a measurement.
    MAX_SANE_MS = PENDING_TTL * 1000

    class << self
      # Called from Resque.push with the exact encoded payload string that
      # was written to the queue.
      def track(queue, raw_payload)
        key = pending_key(queue, raw_payload)

        Resque.redis.rpush(key, now_ms)
        Resque.redis.expire(key, PENDING_TTL)
      end

      # Called from Resque.pop with the exact encoded payload string that
      # came off the queue.
      def record(queue, raw_payload)
        enqueued_at = Resque.redis.lpop(pending_key(queue, raw_payload))

        unless enqueued_at
          Stat << "latency_unmatched:#{queue}"
          return
        end

        delta = now_ms - enqueued_at.to_i

        if delta < 0 || delta > MAX_SANE_MS
          Stat << "latency_discarded:#{queue}"
          return
        end

        Stat.incr("latency_ms:#{queue}", delta)
        Stat << "latency_count:#{queue}"
      end

      # Called from Job.destroy: destroy removes every queue entry matching
      # the payload, and identical payloads share one digest, so deleting
      # the companion list whole is exact.
      def forget(queue, raw_payload)
        Resque.redis.del(pending_key(queue, raw_payload))
      end

      # Called from Resque.remove_queue: the queue's jobs are gone, so all
      # of its companion entries are orphans.
      def sweep_queue(queue)
        keys = Resque.redis.keys("#{KEY_PREFIX}:#{queue}:*")
        Resque.redis.del(*keys) unless keys.empty?
      end

      private

      def pending_key(queue, raw_payload)
        "#{KEY_PREFIX}:#{queue}:#{Digest::MD5.hexdigest(raw_payload)}"
      end

      def now_ms
        (Time.now.to_f * 1000).round
      end
    end
  end
end
