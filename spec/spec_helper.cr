require "spec"
require "../src/opentelemetry-sdk.cr"
require "./test_exporter_spec"

clear_env

# Ensure that no existing environment variables mess with spec operation,
# since environment variables supercede code/config settings.
def clear_env
  ENV.keys.select(&.starts_with?("OTEL")).each do |key|
    ENV.delete(key)
  end
end

def checkout_config(clear : Bool = true, &)
  config = OpenTelemetry.config
  clear_env if clear
  yield
  clear_env if clear
  OpenTelemetry.config = config
end

def rand_time_span
  Time::Span.new(nanoseconds: ((rand / 1000) * 1_000_000_000).to_i64)
end

# def iterate_span_nodes(span, indent, buffer)
#   return if span.nil?

#   buffer << "#{" " * indent}#{span.name}"
#   if span && span.children
#     span.children.each do |child|
#       iterate_span_nodes(child, indent + 2, buffer)
#     end
#   end

#   buffer
# end
def iterate_tracer_spans(tracer)
  tracer.output_stack
end

class FindJson
  @buffer : String = ""

  def self.from_io(io : IO::Memory)
    io.rewind

    json_finder = FindJson.new(io.gets_to_end)
    io.clear

    traces = [] of JSON::Any
    while json = json_finder.pull_json
      traces << JSON.parse(json)
    end

    client_traces = traces.reject { |trace| trace.size == 0 }.select { |trace| trace["spans"][0]["kind"] == 3 }
    server_traces = traces.reject { |trace| trace.size == 0 }.reject { |trace| trace["spans"][0]["kind"] == 3 }

    {client_traces, server_traces}
  end

  def initialize(@buffer)
  end

  def pull_json(buf)
    @buffer = @buffer + buf

    pull_json
  end

  def pull_json
    return nil if @buffer.empty?

    pos = 0
    start_pos = -1
    lefts = 0
    rights = 0
    while pos < @buffer.size
      if @buffer[pos] == '{'
        lefts = lefts + 1
        start_pos = pos if start_pos == -1
      end
      if @buffer[pos] == '}'
        rights = rights + 1
      end
      break if lefts > 0 && lefts == rights

      pos += 1
    end

    json = @buffer[start_pos..pos]
    @buffer = @buffer[pos + 1..-1]

    json
  end
end

class FixedClock < OpenTelemetry::Clock
  def initialize(@now : Time, @monotonic : Time::Span)
  end

  def utc : Time
    @now
  end

  def monotonic : Time::Span
    @monotonic
  end
end
