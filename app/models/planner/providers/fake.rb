module Planner
  module Providers
    class Fake
      attr_reader :contexts

      # An Exception in the script is raised, which lets tests simulate a provider outage.
      def initialize(responses)
        @responses = responses.dup
        @contexts = []
      end

      # With a block, yields the card and then each added item in turn, like the streaming provider does.
      def call(context, &on_partial)
        contexts << context.deep_dup
        response = @responses.shift
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
