# frozen_string_literal: true

module ActionDispatch
  module Http
    module FilterPathTokensInLogs
      PATH_TOKEN_SEGMENT = %r{\A/(sign_in|invitations|p)/[^/?]+}

      def filtered_path
        @filtered_path ||= begin
          filtered = path.sub(PATH_TOKEN_SEGMENT) { "/#{$1}/[FILTERED]" }
          query_string.empty? ? filtered : "#{filtered}?#{filtered_query_string}"
        end
      end
    end
  end
end

ActionDispatch::Request.prepend(ActionDispatch::Http::FilterPathTokensInLogs)
