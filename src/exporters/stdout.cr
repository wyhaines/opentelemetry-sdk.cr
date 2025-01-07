require "./buffered_base"

module OpenTelemetry
  class Exporter
    class Stdout < Base
      def start
        loop_and_receive
      end

      def handle(elements : Array(Elements))
        elements.each do |element|
          puts element.to_json
        end
      end
    end
  end
end
