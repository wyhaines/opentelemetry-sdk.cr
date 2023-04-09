require "./spec_helper"

describe OpenTelemetry do
  before_each do
    # Ensure that global state is always reset to a known starting point
    # before each spec runs.
    OpenTelemetry.configure do |config|
      config.service_name = "my_app_or_library"
      config.service_version = "1.1.1"
      config.exporter = OpenTelemetry::Exporter.new
    end
  end

  it "default configuration is setup as expected" do
    OpenTelemetry.config.service_name.should eq "my_app_or_library"
    OpenTelemetry.config.service_version.should eq "1.1.1"
    OpenTelemetry.config.exporter.should be_a OpenTelemetry::Exporter
  end

  it "can create a trace with arguments passed to the class method" do
    trace = OpenTelemetry.trace_provider(
      "my_app_or_library",
      "1.2.3",
      OpenTelemetry::Exporter.new).trace

    trace.service_name.should eq "my_app_or_library"
    trace.service_version.should eq "1.2.3"
    trace.exporter.should be_a OpenTelemetry::Exporter
  end

  it "substitutes the global provider configuration when values are not provided via method argument initialization" do
    trace = OpenTelemetry.trace_provider("my_app_or_library2").trace
    trace.service_name.should eq "my_app_or_library2"
    trace.service_version.should eq "1.1.1"
    trace.exporter.should be_a OpenTelemetry::Exporter
  end

  it "only creates a new TraceProvider when needed" do
    tp1 = OpenTelemetry.trace_provider
    tp2 = OpenTelemetry.trace_provider
    tp3 = OpenTelemetry.trace_provider("beat of my own drum")
    tp4 = OpenTelemetry.trace_provider
    tp1.should eq tp2
    tp1.should_not eq tp3
    tp3.should eq tp4
  end

  it "can create a trace via a block passed to the class method" do
    trace = OpenTelemetry.trace_provider do |t|
      t.service_name = "my_app_or_library"
      t.service_version = "1.2.3"
      t.exporter = OpenTelemetry::Exporter.new
    end.trace

    trace.service_name.should eq "my_app_or_library"
    trace.service_version.should eq "1.2.3"
    trace.exporter.should be_a OpenTelemetry::Exporter
  end

  it "substitutes the global provider configuration when values are not set via block initialization" do
    trace = OpenTelemetry.trace_provider do |t|
      t.service_version = "2.2.2"
    end.trace

    trace.service_name.should eq "my_app_or_library"
    trace.service_version.should eq "2.2.2"
    trace.exporter.should be_a OpenTelemetry::Exporter
  end

  it "can trace using the macro version of in_span with blocks" do
    checkout_config do
      OpenTelemetry.configure do |config|
        config.exporter = OpenTelemetry::Exporter.new(variant: :null)
      end
      trace = nil
      OpenTelemetry.in_span("request") do |span|
        trace = Fiber.current.current_trace
        span.set_attribute("verb", "GET")
        span.set_attribute("url", "http://example.com/foo")
        sleep(rand/1000)
        span.add_event("dispatching to handler")
        OpenTelemetry.in_span("handler") do |child_span|
          sleep(rand/1000)
          child_span.add_event("dispatching to database")
          OpenTelemetry.in_span("db") do |db_span|
            db_span.add_event("querying database")
            sleep(rand/1000)
          end
          OpenTelemetry.in_span("external api") do |api_span|
            api_span.add_event("querying api")
            sleep(rand/1000)
          end
          sleep(rand/1000)
        end
      end

      iterate_tracer_spans(trace.not_nil!).map(&.name).should eq ["request", "handler", "external api", "db"]
    end
  end

  it "can trace using the macro version of in_span without blocks" do
    checkout_config do
      OpenTelemetry.configure do |config|
        config.exporter = OpenTelemetry::Exporter.new(variant: :null)
      end
      trace = nil
      begin
        span = OpenTelemetry.in_span("request")
        trace = Fiber.current.current_trace
        span.set_attribute("verb", "GET")
        span.set_attribute("url", "http://example.com/foo")
        sleep(rand/1000)
        span.add_event("dispatching to handler")
        OpenTelemetry.in_span("handler") do |child_span|
          sleep(rand/1000)
          child_span.add_event("dispatching to database")
          OpenTelemetry.in_span("db") do |db_span|
            db_span.add_event("querying database")
            sleep(rand/1000)
          end
          OpenTelemetry.in_span("external api") do |api_span|
            api_span.add_event("querying api")
            sleep(rand/1000)
          end
          sleep(rand/1000)
        end
      ensure
        OpenTelemetry.close_span
      end

      iterate_tracer_spans(trace.not_nil!).map(&.name).should eq ["request", "handler", "external api", "db"]
    end
  end

  it "sets clock and reverts after block" do
    original_clock = OpenTelemetry.clock

    clock = FixedClock.new(now: Time.utc, monotonic: Time::Span.new(nanoseconds: 5))

    OpenTelemetry.with_clock(clock) do
      OpenTelemetry.clock.should eq(clock)
    end

    OpenTelemetry.clock.should eq(original_clock)
  end
end
