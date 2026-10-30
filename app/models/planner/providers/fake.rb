module Planner
  module Providers
    class Fake
      attr_reader :contexts

      def initialize(responses)
        @responses = responses.dup
        @contexts = []
      end

      def call(context)
        contexts << context.deep_dup
        response = @responses.shift
        raise "No scripted Planner response remains" unless response

        response
      end
    end
  end
end
