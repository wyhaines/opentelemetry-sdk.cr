require "opentelemetry-api/src/api/abstract_status"

module OpenTelemetry
  struct Status < OpenTelemetry::API::AbstractStatus
    alias StatusCode = OpenTelemetry::API::AbstractStatus::StatusCode

    property code : StatusCode
    property message : String

    def initialize(@code = StatusCode::Unset, @message = "")
    end

    def ok!(message = nil)
      @code = StatusCode::Ok
      @message = message if message
    end

    def error!(message = nil)
      @code = StatusCode::Error
      @message = message if message
    end

    def unset!(message = nil)
      @code = StatusCode::Unset
      @message = message if message
    end

    def pb_status_code
      case @code
      when StatusCode::Unset
        Proto::Trace::V1::Status::StatusCode::STATUSCODEUNSET
      when StatusCode::Ok
        Proto::Trace::V1::Status::StatusCode::STATUSCODEOK
      else
        Proto::Trace::V1::Status::StatusCode::STATUSCODEERROR
      end
    end

    def to_protobuf
      OpenTelemetry::Proto::Trace::V1::Status.new(
        message: @message,
        code: pb_status_code
      )
    end

    def to_json
      JSON.build do |json|
        self.to_json(json)
      end
    end

    def to_json(json : JSON::Builder)
      json.object do
        json.field "code", @code.value
        json.field "message", @message
      end
    end
  end
end

