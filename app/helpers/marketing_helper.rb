module MarketingHelper
  def marketing_page?
    controller_name.in?(%w[landing marketing_pages])
  end

  def marketing_url(page)
    page.home? ? root_url : root_url.chomp("/") + page.path
  end
end
