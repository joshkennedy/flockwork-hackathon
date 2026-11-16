module Planner
  module Providers
    class Fake
      attr_reader :contexts

      def initialize(responses = [], &response_for_context)
        @responses = responses.dup
        @response_for_context = response_for_context
        @contexts = []
      end

      def call(context, &on_partial)
        contexts << context.deep_dup
        response = @responses.shift || @response_for_context&.call(context.deep_dup)
        raise "No scripted Planner response remains" unless response
        raise response if response.is_a?(Exception)

        on_partial&.call(card: response.card, added: [])
        response.added.each_index do |index|
          on_partial&.call(card: response.card, added: response.added.first(index + 1))
        end
        response
      end
    end
  end
end
