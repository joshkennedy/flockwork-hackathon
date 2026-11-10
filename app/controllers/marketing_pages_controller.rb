class MarketingPagesController < ApplicationController
  allow_unauthenticated_access

  def show
    @page = MarketingPage.find(params[:slug])
    return head :not_found unless @page

    render "marketing_pages/#{@page.template}"
  rescue ActionView::MissingTemplate
    head :not_found
  end
end
