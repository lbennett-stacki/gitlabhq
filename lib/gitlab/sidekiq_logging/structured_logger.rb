# frozen_string_literal: true

require 'active_record'
require 'active_record/log_subscriber'
require 'sidekiq/job_logger'
require 'sidekiq/job_retry'

module Gitlab
  module SidekiqLogging
    class StructuredLogger < Sidekiq::JobLogger
      include LogsJobs

      def call(job, queue)
        started_time = get_time
        base_payload = parse_job(job)

        ActiveRecord::LogSubscriber.reset_runtime

        Sidekiq.logger.info log_job_start(job, base_payload)

        yield

        Sidekiq.logger.info log_job_done(job, started_time, base_payload)
      rescue Sidekiq::JobRetry::Handled => job_exception
        # Sidekiq::JobRetry::Handled is raised by the internal Sidekiq
        # processor. It is a wrapper around real exception indicating an
        # exception is already handled by the Job retrier. The real exception
        # should be unwrapped before being logged.
        #
        # For more information:
        # https://github.com/mperham/sidekiq/blob/v5.2.7/lib/sidekiq/processor.rb#L173
        Sidekiq.logger.warn log_job_done(job, started_time, base_payload, job_exception.cause || job_exception)

        raise
      rescue StandardError => job_exception
        Sidekiq.logger.warn log_job_done(job, started_time, base_payload, job_exception)

        raise
      end

      private

      def add_instrumentation_keys!(job, output_payload)
        output_payload.merge!(job[:instrumentation].stringify_keys) if job[:instrumentation]
      end

      def add_logging_extras!(job, output_payload)
        output_payload.merge!(
          job.select { |key, _| key.to_s.start_with?("#{ApplicationWorker::LOGGING_EXTRA_KEY}.") }
        )
      end

      def log_job_start(job, payload)
        payload['message'] = "#{base_message(payload)}: start"
        payload['job_status'] = 'start'

        scheduling_latency_s = ::Gitlab::InstrumentationHelper.queue_duration_for_job(payload)
        payload['scheduling_latency_s'] = scheduling_latency_s if scheduling_latency_s

        enqueue_latency_s = ::Gitlab::InstrumentationHelper.enqueue_latency_for_scheduled_job(payload)
        payload['enqueue_latency_s'] = enqueue_latency_s if enqueue_latency_s

        payload
      end

      def log_job_done(job, started_time, payload, job_exception = nil)
        payload = payload.dup
        add_instrumentation_keys!(job, payload)
        add_logging_extras!(job, payload)

        elapsed_time = elapsed(started_time)
        add_time_keys!(elapsed_time, payload)

        message = base_message(payload)

        payload['load_balancing_strategy'] = job['load_balancing_strategy'] if job['load_balancing_strategy']
        payload['dedup_wal_locations'] = job['dedup_wal_locations'] if job['dedup_wal_locations'].present?

        job_status = if job_exception
                       'fail'
                     elsif job['dropped']
                       'dropped'
                     elsif job['deferred']
                       'deferred'
                     else
                       'done'
                     end

        payload['message'] = "#{message}: #{job_status}: #{payload['duration_s']} sec"
        payload['job_status'] = job_status
        payload['job_deferred_by'] = job['deferred_by'] if job['deferred']
        payload['deferred_count'] = job['deferred_count'] if job['deferred']

        Gitlab::ExceptionLogFormatter.format!(job_exception, payload) if job_exception

        db_duration = ActiveRecord::LogSubscriber.runtime
        payload['db_duration_s'] = Gitlab::Utils.ms_to_round_sec(db_duration)

        job_urgency = payload['class'].safe_constantize&.get_urgency.to_s
        unless job_urgency.empty?
          payload['urgency'] = job_urgency
          payload['target_duration_s'] = Gitlab::Metrics::SidekiqSlis.execution_duration_for_urgency(job_urgency)
        end

        payload
      end

      def add_time_keys!(time, payload)
        payload['duration_s'] = time[:duration].round(Gitlab::InstrumentationHelper::DURATION_PRECISION)
        payload['completed_at'] = Time.now.utc.to_f
      end

      def elapsed(t0)
        t1 = get_time
        { duration: t1[:now] - t0[:now] }
      end

      def get_time
        { now: current_time }
      end

      def current_time
        Gitlab::Metrics::System.monotonic_time
      end
    end
  end
end
