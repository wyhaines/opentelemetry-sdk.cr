require "opentelemetry-api/src/api/abstract_span"

module OpenTelemetry
  class Span < OpenTelemetry::API::AbstractSpan
    alias Kind = API::AbstractSpan::Kind
  end
end
