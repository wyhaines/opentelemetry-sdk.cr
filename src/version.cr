module OpenTelemetry
  module SDK
    {% begin %}
    VERSION = {{ read_file("#{__DIR__}/../VERSION").chomp }}
    {% end %}
  end

  VERSION = SDK::VERSION
end
