require "opentelemetry-api/interfaces"
require "./ext"
require "csuuid"
require "./clock"
require "./resource"
require "./trace_flags"
require "./name"
require "./version"
require "./aliases"
require "./trace_provider"
require "./meter_provider"
require "./log_provider"
require "./text_map_propagator"
require "./exporter"
require "random/pcg32"

# ```
#
# ## Global Trace Provider
# ----------------------------------------------------------------
#
# OpenTelemetry.configure do |config|
#   config.service_name = "my_app_or_library"
#   config.service_version = "1.1.1"
#   config.exporter = OpenTelemetry::Exporter.new(variant: :stdout)
# end
#
# trace = OpenTelemetry.trace_provider("my_app_or_library", "1.1.1").trace
# trace = OpenTelemetry.trace_provider do |provider|
#   provider.service_name = "my_app_or_library"
#   provider.service_version = "1.1.1"
# end.trace
#
# ## Trace Providers as Objects With Unique Configuration
# ----------------------------------------------------------------
#
# provider_a = OpenTelemetry::TraceProvider.new("my_app_or_library", "1.1.1")
# provider_a.exporter = OpenTelemetry::Exporter.new(variant: :stdout)
#
# provider_b = OpenTelementry::TraceProvider.new do |config|
#   config.service_name = "my_app_or_library"
#   config.service_version = "1.1.1"
#   config.exporter = OpenTelemetry::Exporter.new(variant: :stdout)
# end
#
# ## Getting a Trace From a Provider Object
# ----------------------------------------------------------------
#
# trace = provider_a.trace # Inherit all configuration from the Provider Object
#
# trace = provider_a.trace("microservice foo", "1.2.3") # Override the configuration
#
# trace = provider_a.trace do |provider|
#   provider.service_name = "microservice foo"
#   provider.service_version = "1.2.3"
# end.trace
#
# ## Creating Spans Using a Trace
# ----------------------------------------------------------------
#
# trace.in_span("request") do |span|
#   span.set_attribute("verb", "GET")
#   span.set_attribute("url", "http://example.com/foo")
#   span.add_event("dispatching to handler")
#   trace.in_span("handler") do |child_span|
#     child_span.add_event("handling request")
#     trace.in_span("db") do |child_span|
#       child_span.add_event("querying database")
#     end
#   end
# end
module OpenTelemetry
  CSUUID.prng = Random::PCG32.new
  INSTANCE_ID = CSUUID.unique.to_s
  # The `config` class property provides direct access to the global default TracerProvider configuration.
  class_property config : TraceProvider::Configuration = TraceProvider::Configuration::Factory.build

  # `provider` class property provides direct access to the global default Tracerprovider instance.
  class_property provider : TraceProvider = TraceProvider.new.configure!(@@config)

  # `clock` class property allows alternative implementations for testing or simulations
  class_property clock : Clock = TimeClock.new

  # Use this method to configure the global trace provider. The provided block will receive a `OpenTelemetry::Provider::Configuration::Factory`
  # instance, which will be used to generate a `OpenTelemetry::Provider::Configuration` struct instance.
  def self.configure(&block : TraceProvider::Configuration::Factory ->)
    @@config = TraceProvider::Configuration::Factory.build do |config_block|
      block.call(config_block)
    end

    provider.configure!(@@config)

    @@config
  end

  # Calling `configure` with no block results in a global TracerProvider being configured with the default configuration.
  # This is useful in cases where it is known that environment variable configuration is going to be used exclusively.
  #
  # ```
  # # Depend on SDK environment variables ([https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/sdk-environment-variables.md](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/sdk-environment-variables.md))
  # # for all configuration.
  # OpenTelememtry.configure
  # ```
  #
  def self.configure
    configure do |_|
    end
  end

  # Return the global `TracerProvider` instance.
  def self.trace_provider
    provider
  end

  # Alias. The spec uses `TracerProvider`s, which manage `Tracer`s,
  # but which have internal methods and entities like `trace_id` and `TraceState`
  # and `TraceFlags`. Then this library was initially written, I opted for uniformly
  # consistent naming, but that violates the spec. Future versions will move towards
  # deprecating the uniform naming, in places where that naming violates the spec.
  # This is here to start preparing for that transition.
  def self.tracer_provider
    trace_provider
  end

  # Configure and return a new `TracerProvider` instance, using the provided block.
  # The configured `TracerProvider` will have the configuration from the global instance
  # merged with it, which means that given no additional configuration, the newly
  # provided `TracerProvider` will have the same configuration as the global `TracerProvider`
  def self.trace_provider(&block : TraceProvider::Configuration::Factory ->)
    self.provider = TraceProvider.new(@@config) do |cfg|
      block.call(cfg)
    end

    provider
  end

  # Alias. The spec uses `TracerProvider`s, which manage `Tracer`s,
  # but which have internal methods and entities like `trace_id` and `TraceState`
  # and `TraceFlags`. Then this library was initially written, I opted for uniformly
  # consistent naming, but that violates the spec. Future versions will move towards
  # deprecating the uniform naming, in places where that naming violates the spec.
  # This is here to start preparing for that transition.
  def self.tracer_provider(&block : TraceProvider::Configuration::Factory ->)
    self.trace_provider(&block)
  end

  # Configure and return a new `TracerProvider` instance, using the method arguments.
  # The configured `TracerProvider` will have the configuration from the global instance
  # merged with it, which means that given no additional configuration, the newly
  # provided `TracerProvider` will have the same configuration as the global `TracerProvider`
  def self.trace_provider(
    service_name : String? = nil,
    service_version : String? = nil,
    exporter = nil
  )
    if !service_name.nil? || !service_version.nil? || !exporter.nil?
      self.provider = TraceProvider.new(
        service_name: service_name || ENV["OTEL_SERVICE_NAME"]? || "",
        service_version: service_version || "",
        exporter: exporter || Exporter.new(:abstract))
      provider.merge_configuration(@@config)
    end
    provider
  end

  # Alias. The spec uses `TracerProvider`s, which manage `Tracer`s,
  # but which have internal methods and entities like `trace_id` and `TraceState`
  # and `TraceFlags`. Then this library was initially written, I opted for uniformly
  # consistent naming, but that violates the spec. Future versions will move towards
  # deprecating the uniform naming, in places where that naming violates the spec.
  # This is here to start preparing for that transition.
  def self.tracer_provider(
    service_name : String? = nil,
    service_version : String? = nil,
    exporter = nil
  )
    self.trace_provider(
      service_name: service_name,
      service_version: service_version,
      exporter: exporter)
  end

  # Returns the current active `Span` in the current fiber, or nil if there is no currently
  # active `Span`.
  def self.current_span
    Fiber.current.current_span
  end

  # Returns the currently active `Tracer` in the current fiber. If there is no currently active
  # `Tracer`, then a new `Tracer` will be created and returned. Once a new `Tracer` has been
  # created, it will remain active until at least one `Span` has been opened in it, and then
  # subsequently closed.
  def self.trace
    trace = Fiber.current.current_trace
    r = trace ? trace : trace_provider.trace
    Fiber.current.current_trace = r

    r
  end

  # Alias. The spec uses `TracerProvider`s, which manage `Tracer`s,
  # but which have internal methods and entities like `trace_id` and `TraceState`
  # and `TraceFlags`. Then this library was initially written, I opted for uniformly
  # consistent naming, but that violates the spec. Future versions will move towards
  # deprecating the uniform naming, in places where that naming violates the spec.
  # This is here to start preparing for that transition.
  def self.tracer
    trace
  end

  # Invokes the provided block with either the currently active `Tracer`, if one
  # exists, or a new `Tracer`, if there isn't one currently active. The block version
  # of opening a new `Tracer` ensures that only the code that executes between when
  # the block starts executing, and when it finishes executing, will be included in
  # the finished trace.
  def self.trace(&)
    trace = self.trace
    yield trace

    trace
  end

  # Alias. The spec uses `TracerProvider`s, which manage `Tracer`s,
  # but which have internal methods and entities like `trace_id` and `TraceState`
  # and `TraceFlags`. Then this library was initially written, I opted for uniformly
  # consistent naming, but that violates the spec. Future versions will move towards
  # deprecating the uniform naming, in places where that naming violates the spec.
  # This is here to start preparing for that transition.
  def self.tracer(&)
    tracer = self.tracer
    yield tracer

    tracer
  end

  macro in_span(span_name, &block)
  {%
    if block
      span_arg = block.args.first.id
      if span_arg == "_".id
        span_arg = "__tmp_span_arg__".id
      end
    else
      span_arg = nil
    end
  %}
  {% if span_arg %}
  OpenTelemetry.trace.in_span({{ span_name }}) do |{{ span_arg }}|
    {{ span_arg }}["code.filepath"] = __FILE__
    {{ span_arg }}["code.lineno"] = __LINE__
    {{ span_arg }}["code.function"] = \{{ "#{@def ? @def.name : "@toplevel".id}" }}
    {{ span_arg }}["code.namespace"] = \{{ "#{@type.name}" }}
    {{ span_arg }}["thread.id"] = Fiber.current.object_id
    {{ span_arg }}["thread.name"] = Fiber.current.name.to_s
      {{ block.body }}
    end
  {% else %}
  (begin
    %span = OpenTelemetry.trace.in_span({{ span_name }})
    %span["code.filepath"] = __FILE__
    %span["code.lineno"] = __LINE__
    %span["code.function"] = \{{ "#{@def ? @def.name : "@toplevel".id}" }}
    %span["code.namespace"] = \{{ "#{@type.name}" }}
    %span["thread.id"] = Fiber.current.object_id
    %span["thread.name"] = Fiber.current.name.to_s

    %span
  end)
  {% end %}
  end

  macro close_span
    Fiber.current.current_trace.try(&.close_span)
  end

  def self.instrumentation_scope
    Proto::Common::V1::InstrumentationScope.new(
      name: NAME,
      version: SDK::VERSION,
    )
  end

  def self.instrumentation_library
    instrumentation_scope
  end

  def self.handle_error(error)
  end

  def self.with_clock(clock : Clock, &)
    original_clock = self.clock

    begin
      self.clock = clock
      yield
    ensure
      self.clock = original_clock
    end
  end
end
