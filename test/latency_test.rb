require 'test_helper'

describe "Resque::Latency" do
  def pending_keys(queue = :people)
    Resque.redis.keys("#{Resque::Latency::KEY_PREFIX}:#{queue}:*")
  end

  it "records latency for a pushed and popped job" do
    Resque.push(:people, 'class' => 'SomeJob', 'args' => %w(a))
    Resque.pop(:people)

    assert_equal 1, Resque::Stat["latency_count:people"]
    assert_operator Resque::Stat["latency_ms:people"], :>=, 0
    assert_equal 0, Resque::Stat["latency_unmatched:people"]
    assert_empty pending_keys
  end

  it "pairs duplicate payloads FIFO and cleans up after itself" do
    2.times { Resque.push(:people, 'class' => 'SomeJob', 'args' => %w(a)) }

    assert_equal 1, pending_keys.size

    2.times { Resque.pop(:people) }

    assert_equal 2, Resque::Stat["latency_count:people"]
    assert_equal 0, Resque::Stat["latency_unmatched:people"]
    assert_empty pending_keys
  end

  it "counts a pop with no companion entry as unmatched" do
    # Simulate a job enqueued by code without latency tracking (e.g. the
    # previous gem version during a rolling deploy)
    Resque.data_store.push_to_queue(:people, Resque.encode('class' => 'SomeJob', 'args' => []))

    Resque.pop(:people)

    assert_equal 1, Resque::Stat["latency_unmatched:people"]
    assert_equal 0, Resque::Stat["latency_count:people"]
  end

  it "discards deltas outside sane bounds instead of polluting the sum" do
    # A mispaired orphan: an ancient timestamp left behind by a crash
    payload = Resque.encode('class' => 'SomeJob', 'args' => %w(a))
    key = "#{Resque::Latency::KEY_PREFIX}:people:#{Digest::MD5.hexdigest(payload)}"
    Resque.redis.rpush(key, 1)

    Resque.data_store.push_to_queue(:people, payload)
    Resque.pop(:people)

    assert_equal 1, Resque::Stat["latency_discarded:people"]
    assert_equal 0, Resque::Stat["latency_count:people"]
  end

  it "sets a TTL on companion entries so orphans self-clean" do
    Resque.push(:people, 'class' => 'SomeJob', 'args' => %w(a))

    ttl = Resque.redis.ttl(pending_keys.first)
    assert_operator ttl, :>, 0
    assert_operator ttl, :<=, Resque::Latency::PENDING_TTL
  end

  it "drops companion entries when a job is destroyed by class and args" do
    Resque::Job.create(:people, SomeJob, "destroy-me")
    Resque::Job.create(:people, SomeJob, "keep-me")

    Resque::Job.destroy(:people, SomeJob, "destroy-me")

    assert_equal 1, pending_keys.size

    Resque.pop(:people)

    assert_equal 1, Resque::Stat["latency_count:people"]
    assert_equal 0, Resque::Stat["latency_unmatched:people"]
  end

  it "drops companion entries when jobs are destroyed class-wide" do
    Resque::Job.create(:people, SomeJob, "one")
    Resque::Job.create(:people, SomeJob, "two")

    Resque::Job.destroy(:people, SomeJob)

    assert_empty pending_keys
  end

  it "sweeps companion entries when a queue is removed" do
    Resque::Job.create(:people, SomeJob, "doomed")

    Resque.remove_queue(:people)

    assert_empty pending_keys
  end
end
