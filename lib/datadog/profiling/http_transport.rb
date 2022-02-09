# typed: true

module Datadog
  module Profiling
    # Used to report profiling data to Datadog.
    # Methods prefixed with _native_ are implemented in `http_transport.c`
    class HttpTransport
      def initialize(agent_settings:, site:, api_key:, tags:, upload_timeout_seconds:)
        @upload_timeout_milliseconds = (upload_timeout_seconds * 1_000).to_i

        validate_agent_settings(agent_settings)

        # FIXME: Handle/convert tags?
        # FIXME: Strict types in tags

        @libddprof_exporter =
          if site && api_key && agentless_allowed?
            create_agentless_exporter(site, api_key, tags)
          else
            create_agent_exporter(base_url_from(agent_settings), tags)
          end
      end

      def export(flush)
        do_export(
          libddprof_exporter: @libddprof_exporter,
          upload_timeout_milliseconds: @upload_timeout_milliseconds,

          # why "timespec"?
          # libddprof represents time using POSIX's struct timespec, see
          # https://www.gnu.org/software/libc/manual/html_node/Time-Types.html
          # aka they separate the seconds part from the nanoseconds part
          start_timespec_seconds: flush.start.tv_sec,
          start_timespec_nanoseconds: flush.start.tv_nsec,
          finish_timespec_seconds: flush.finish.tv_sec,
          finish_timespec_nanoseconds: flush.finish.tv_nsec,

          pprof_file_name: flush.pprof_file_name,
          pprof_data: flush.pprof_data,
          code_provenance_file_name: flush.code_provenance_file_name,
          code_provenance_data: flush.code_provenance_data,
        )
      end

      private

      def base_url_from(agent_settings)
        "#{agent_settings.ssl ? 'https' : 'http'}://#{agent_settings.hostname}:#{agent_settings.port}/"
      end

      # FIXME: Re-evaluate our plans for these before merging this anywhere. We should at least provide clearer error
      # messages and next steps for customers, the current messages are too cryptic. Ideally, we would still support
      # Unix Domain Socket for reporting data.
      def validate_agent_settings(agent_settings)
        if agent_settings.adapter == Datadog::Transport::Ext::UnixSocket::ADAPTER
          raise ArgumentError, 'Unsupported agent configuration for profiling: Unix Domain Sockets are currently unsupported.'
        end

        # TODO: We may need to handle the hash version of the transport_options
        # if https://github.com/DataDog/dd-trace-rb/pull/1886 is rejected

        if agent_settings.deprecated_for_removal_transport_configuration_proc
          raise ArgumentError, 'Unsupported agent configuration for profiling: custom c.tracer.transport_options is currently unsupported.'
        end
      end

      def agentless_allowed?
        Core::Environment::VariableHelpers.env_to_bool(Profiling::Ext::ENV_AGENTLESS, false)
      end

      def create_agentless_exporter(site, api_key, tags)
        self.class._native_create_agentless_exporter(site, api_key, tags)
      end

      def create_agent_exporter(base_url, tags)
        self.class._native_create_agent_exporter(base_url, tags)
      end

      def do_export(
        libddprof_exporter:,
        upload_timeout_milliseconds:,
        start_timespec_seconds:,
        start_timespec_nanoseconds:,
        finish_timespec_seconds:,
        finish_timespec_nanoseconds:,
        pprof_file_name:,
        pprof_data:,
        code_provenance_file_name:,
        code_provenance_data:
      )
        self.class._native_do_export(
          libddprof_exporter,
          upload_timeout_milliseconds,
          start_timespec_seconds,
          start_timespec_nanoseconds,
          finish_timespec_seconds,
          finish_timespec_nanoseconds,
          pprof_file_name,
          pprof_data,
          code_provenance_file_name,
          code_provenance_data,
        )
      end
    end
  end
end
