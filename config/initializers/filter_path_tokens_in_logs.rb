module ActionDispatch
  module Http
    module FilterPathTokensInLogs
      PATH_TOKEN_SEGMENT = %r{\A/+(sign_in|invitations|p)/+[^/?]+}

      def filtered_path
        super.sub(PATH_TOKEN_SEGMENT) { "/#{$1}/[FILTERED]" }
      end
    end
  end
end

ActionDispatch::Request.prepend(ActionDispatch::Http::FilterPathTokensInLogs)
