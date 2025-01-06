module OpenTelemetry
  module SDK
    {% begin %}
    VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}
    {% end %}
  end

  VERSION = SDK::VERSION
end
