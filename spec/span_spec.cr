require "./spec_helper"
require "json"

describe OpenTelemetry::Span, tags: ["Span"] do
  it "can create a span and set/get attributes on that span" do
    checkout_config do
      span = OpenTelemetry::Span.new
      verb = "GET"
      url = "http://example.com/foo"
      span.set_attribute("verb", verb)
      span["url"] = url
      span["verb"].should eq verb
      span["url"].should eq url
      span.get_attribute("url").value.should eq url
      span["bools"] = true
      span["bools"] = false
      span["bools"].should be_false
      span.get_attribute("bools") << true
      span["bools"].should eq [false, true]
      span["headers"] = Array(String).new
      span.get_attribute("headers") << "Content-Type: text/plain"
      span.get_attribute("headers") << "Content-Length: 23"
      span["headers"].should eq ["Content-Type: text/plain", "Content-Length: 23"]
      span.id.should_not be_nil
      span.id.should eq span.context.span_id
      span.add_event("Test Event") do |event|
        event["foo"] = "bar"
      end
      span.status.code.should eq OpenTelemetry::Status::StatusCode::Unset
      span.status.ok!("Everything is fine.")
      span.status.code.should eq OpenTelemetry::Status::StatusCode::Ok

      span.kind.should eq OpenTelemetry::Span::Kind::Internal
      span.server!
      span.kind.should eq OpenTelemetry::Span::Kind::Server

      span.to_protobuf
      # validate the protobuf structure.
    end
  end

  it "can set events on a span" do
    checkout_config do
      span = OpenTelemetry::Span.new
      span.set_attribute("verb", "GET")
      span.set_attribute("url", "http://example.com/foo")
      span.add_event("dispatching to handler") do |event|
        event["verb"] = "GET"
        event["url"] = "http://example.com/foo"
      end
      error_time = Time.utc.to_s
      span.add_event("error") do |event|
        event["error"] = "error"
        event["time"] = error_time
        event["message"] = "There was a really bad error."
      end
      span.events.size.should eq 2
      event = span.events.first
      event.name.should eq "dispatching to handler"
      event.attributes["verb"].value.should eq "GET"
      event.attributes["url"].value.should eq "http://example.com/foo"
      event = span.events.last
      event.name.should eq "error"
      event.attributes["error"].value.should eq "error"
      event.attributes["time"].value.should eq error_time
      event.attributes["message"].value.should eq "There was a really bad error."
    end
  end

  it "can use a trace to create a span" do
    checkout_config do
      provider = OpenTelemetry::TraceProvider.new(
        service_name: "my_app_or_library",
        service_version: "1.1.1",
        exporter: OpenTelemetry::Exporter.new(variant: :null))
      trace = provider.trace do |trace_setup|
        trace_setup.service_name = "microservice"
        trace_setup.service_version = "1.2.3"
      end
      trace.in_span("request") do |span|
        span.set_attribute("verb", "GET")
        span.set_attribute("url", "http://example.com/foo")
        span.add_event("dispatching to handler")
      end
    end
  end

  it "can set a span to all of the defined span kinds" do
    [
      {OpenTelemetry::Span::Kind::Consumer, 5},
      {OpenTelemetry::Span::Kind::Producer, 4},
      {OpenTelemetry::Span::Kind::Client, 3},
      {OpenTelemetry::Span::Kind::Server, 2},
      {OpenTelemetry::Span::Kind::Internal, 1},
      {OpenTelemetry::Span::Kind::Unspecified, 0},
    ].each do |kind, kind_val|
      checkout_config do
        json = ""
        OpenTelemetry.trace.in_span("request") do |span|
          span.kind = kind
          span.is_recording = true
          span.context.trace_flags = OpenTelemetry::TraceFlags::Sampled

          json = span.to_json
        end
        JSON.parse(json)["kind"].as_i.should eq kind_val
      end
    end
  end

  it "can create nested spans" do
    checkout_config do
      provider = OpenTelemetry::TraceProvider.new(
        service_name: "my_app_or_library",
        service_version: "1.1.1",
        exporter: OpenTelemetry::Exporter.new(variant: :null))
      trace = provider.trace do |trace_setup|
        trace_setup.service_name = "microservice"
        trace_setup.service_version = "1.2.3"
      end
      trace.in_span("request") do |span|
        span.set_attribute("verb", "GET")
        span.set_attribute("url", "http://example.com/foo")
        sleep(rand_time_span)
        span.add_event("dispatching to handler")
        trace.in_span("handler") do |child_span|
          sleep(rand_time_span)
          child_span.add_event("dispatching to database")
          trace.in_span("db") do |db_span|
            db_span.add_event("querying database")
            sleep(rand_time_span)
          end
          trace.in_span("external api") do |api_span|
            api_span.add_event("querying api")
            sleep(rand_time_span)
          end
          sleep(rand_time_span)
        end
      end

      iterate_tracer_spans(trace).map(&.name).should eq ["request", "handler", "external api", "db"]
    end
  end
end
