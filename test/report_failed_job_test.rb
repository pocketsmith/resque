require 'test_helper'

# Regression coverage for the 1.27.4.1 fork bug where report_failed_job
# crashed (NoMethodError: Resque::Job has no #[]) BEFORE job.fail ran, so no
# failing job ever reached the failure backend, on_failure hooks (resque-retry)
# never fired, and the failed stats never moved. report_failed_job receives a
# real Resque::Job here — exactly the production call shape.
describe "Worker#report_failed_job" do
  before do
    Resque.redis.flushall
    @worker = Resque::Worker.new(:jobs)
    @job = Resque::Job.new(:jobs, 'class' => 'SomeJob', 'args' => [])
    @job.worker = @worker
  end

  it "records the failure in the failure backend" do
    assert_equal 0, Resque::Failure.count
    @worker.report_failed_job(@job, RuntimeError.new("boom"))
    assert_equal 1, Resque::Failure.count
  end

  it "bumps the global, per-host, per-queue and per-host-per-queue failed stats" do
    @worker.report_failed_job(@job, RuntimeError.new("boom"))
    host = @worker.hostname
    assert_equal 1, Resque::Stat["failed"]
    assert_equal 1, Resque::Stat["failed:#{host}"]
    assert_equal 1, Resque::Stat["failed:#{host}:jobs"]
    assert_equal 1, Resque::Stat["failed:jobs"]
  end

  it "still counts the failure when there is no job (falls back to the worker's queues)" do
    @worker.report_failed_job(nil, RuntimeError.new("boom"))
    assert_equal 1, Resque::Stat["failed"]
    assert_equal 1, Resque::Stat["failed:jobs"]
  end
end
