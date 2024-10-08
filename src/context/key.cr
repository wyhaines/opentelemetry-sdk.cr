require "opentelemetry-api/src/api/abstract_context"

module OpenTelemetry
  struct Context < OpenTelemetry::API::AbstractContext
    struct Key < OpenTelemetry::API::AbstractContext::AbstractKey
      getter name : String
      getter id : CSUUID
      getter context : Context

      def initialize(@name = CSUUID.unique.to_s, @context = Context.current, @id = CSUUID.unique)
      end

      def value
        get
      end

      def get(context = Context.current)
        context[self.name]
      end

      def <=>(other)
        id <=> other.id
      end
    end
  end
end
