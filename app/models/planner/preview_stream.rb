module Planner
  # Broadcasts what the Planner has streamed so far. Partial renders are never saved: the job's final broadcast
  # replaces them, and a page that loads mid-stream converges on the busy marker and the existing refresh checks.
  class PreviewStream
    INTERVAL = 0.2
    # Streamed items are not validated yet, so a malformed one skips this render; the next partial retries.
    SKIPPED_ITEM_ERRORS = [ ArgumentError, KeyError, TypeError, NoMethodError ].freeze

    def initialize(planner_session, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, authorized: -> { true })
      @planner_session = planner_session
      @clock = clock
      @authorized = authorized
      @last_sent_at = nil
      @card_sent = false
      @items_sent = nil
    end

    def push(partial)
      send_card(partial[:card]) if partial[:card] && !@card_sent
      return if @last_sent_at && @clock.call - @last_sent_at < INTERVAL

      send_items(partial[:added])
    end

    private
      def send_card(card)
        @card_sent = true
        # While an answer is pending, its next question lands with the final render, not mid-stream.
        return if @planner_session.pending_answer.present?

        @planner_session.current_card = card.slice("question", "options")
        replace(ActionView::RecordIdentifier.dom_id(@planner_session, :meal_builder), "planner_sessions/meal_builder",
          project:, planner_session: @planner_session)
        @planner_session.restore_attributes([ "current_card" ])
        sent!
      end

      def send_items(added)
        items = expanded(added)
        return if items.nil? || items == @items_sent

        partial = @planner_session.meal_planner? ? "planner_sessions/meal_preview" : "planner_sessions/project_preview"
        locals = { project:, planner_session: @planner_session, visible_items: items, removed_item: nil }
        locals[:pending_errors] = {} unless @planner_session.meal_planner?
        replace("meal-preview", partial, **locals)
        @items_sent = items
        sent!
      end

      def expanded(added)
        Planner::PendingItems.reconcile(
          existing: @planner_session.pending_items,
          added:,
          removed_ids: [],
          project:,
          revision: @planner_session.generation_revision
        ).then { |items| Planner::PendingItems.visible(items) }
      rescue *SKIPPED_ITEM_ERRORS
        nil
      end

      def replace(target, partial, **locals)
        return unless @authorized.call

        PlannerStreamChannel.broadcast_replace_to(@planner_session, target:, partial:, locals:)
      end

      def sent!
        @last_sent_at = @clock.call
      end

      def project
        @planner_session.project
      end
  end
end
