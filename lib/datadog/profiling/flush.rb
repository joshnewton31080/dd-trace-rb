# typed: false
require 'datadog/core/environment/identity'
require 'datadog/core/environment/socket'

module Datadog
  module Profiling
    # Represents a collection of events of a specific type being flushed.
    EventGroup = Struct.new(:event_class, :events)

    # Entity class used to represent metadata for a given profile
    class Flush
      attr_reader \
        :start,
        :finish,
        :pprof_file_name,
        :pprof_data, # gzipped pprof bytes
        :code_provenance_file_name,
        :code_provenance_data # gzipped json bytes

      def initialize(
        start:,
        finish:,
        pprof_file_name:,
        pprof_data:,
        code_provenance_file_name:,
        code_provenance_data:
      )
        @start = start
        @finish = finish
        @pprof_file_name = pprof_file_name
        @pprof_data = pprof_data
        @code_provenance_file_name = code_provenance_file_name
        @code_provenance_data = code_provenance_data
      end
    end
  end
end
