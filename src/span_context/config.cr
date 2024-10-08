require "opentelemetry-api/src/api/span_context/abstract_config"

module OpenTelemetry
  struct SpanContext < OpenTelemetry::API::AbstractSpanContext
    class Config < OpenTelemetry::API::AbstractSpanContext::AbstractConfig
      property trace_id : Slice(UInt8)
      property span_id : Slice(UInt8)
      property parent_id : Slice(UInt8)? = nil
      property trace_flags : TraceFlags
      property trace_state : Hash(String, String) = {} of String => String
      @remote : Bool = false

      def initialize(@trace_id, @span_id, @parent_id = nil)
        @trace_flags = TraceFlags.new(0x00)
      end

      def initialize(inherited_context : SpanContext)
        @trace_id = inherited_context.trace_id
        @trace_state = inherited_context.trace_state
        @trace_flags = inherited_context.trace_flags
        @remote = inherited_context.remote
        @span_id = IdGenerator.span_id
        @parent_id = inherited_context.span_id
      end

      def remote : Bool
        @remote
      end

      def remote=(remote)
        @remote = remote
      end

      def remote? : Bool
        !!@remote
      end
    end
  end
end
