class IconsController < ApplicationController
  allow_unauthenticated_access

  # The color rides in the URL (?c=D69000) so the favicon needs no session and
  # browsers refetch it when a church changes its color.
  def show
    color = "##{params[:c]}".upcase
    color = Organization::DEFAULT_MARK_COLOR unless color.match?(/\A#\h{6}\z/)
    expires_in 1.year, public: true
    render plain: helpers.mark_favicon_svg(color), content_type: "image/svg+xml"
  end
end
