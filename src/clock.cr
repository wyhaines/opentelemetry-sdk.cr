module OpenTelemetry
  abstract class Clock
    abstract def monotonic : Time::Span
    abstract def utc : Time
  end

  class TimeClock < Clock
    @[AlwaysInline]
    def monotonic : Time::Span
      Time.monotonic
    end

    @[AlwaysInline]
    def utc : Time
      Time.utc
    end
  end
end