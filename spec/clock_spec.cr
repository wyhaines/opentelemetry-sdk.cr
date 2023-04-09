require "./spec_helper"

describe OpenTelemetry::Clock do
  it "allows a clock to be set and used for span generation" do
    start = Time.utc
    start_monotonic = Time::Span.new(nanoseconds: 5)
    start_clock = FixedClock.new(start, start_monotonic)

    finish = start.shift(nanoseconds: 100)
    finish_monotonic = start_monotonic + Time::Span.new(nanoseconds: 100)
    finish_clock = FixedClock.new(finish, finish_monotonic)

    checkout_config do
      provider = OpenTelemetry::TraceProvider.new(
        service_name: "my_app_or_library",
        service_version: "1.1.1",
        exporter: OpenTelemetry::Exporter.new(variant: :null))

      trace = provider.trace do |t|
        t.service_name = "microservice"
        t.service_version = "1.2.3"
      end

      span = OpenTelemetry.with_clock(start_clock) do
        trace.in_span("request")
      end

      OpenTelemetry.with_clock(finish_clock) do
        trace.close_span
      end

      span.start.should eq(start_monotonic)
      span.wall_start.should eq(start)

      span.finish.should eq(finish_monotonic)
      span.wall_finish.should eq(finish)
    end
  end
end