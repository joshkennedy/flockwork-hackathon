require "test_helper"

class MarketingPageTest < ActiveSupport::TestCase
  test "every page has unique slug, title and description, and a title under 60 characters" do
    pages = MarketingPage::ALL
    %i[slug title description].each { |field| assert_equal pages.size, pages.map(&field).uniq.size, "duplicate #{field}" }
    pages.each { |page| assert_operator page.title.length, :<, 60, page.slug }
    pages.each { |page| assert page.description.length.between?(70, 170), page.slug }
  end

  test "paths, templates and route names derive from the slug" do
    page = MarketingPage.find("features/sign-ups")
    assert_equal "/features/sign-ups", page.path
    assert_equal "features/sign_ups", page.template
    assert_equal :features_sign_ups, page.route_name
    assert_equal "/", MarketingPage.find("").path
    assert MarketingPage.find("").home?
    assert_nil MarketingPage.find("features/nope")
  end

  test "the seven features and every named scene and photo exist" do
    assert_equal %w[sign-ups tasks schedule budget planner people oversight], MarketingPage.in_section(:feature).map { |page| page.slug.delete_prefix("features/") }
    MarketingPage::ALL.each do |page|
      assert Rails.root.join("app/assets/images/marketing/#{page.scene}.webp").exist?, page.slug if page.scene
      assert Rails.root.join("app/assets/images/marketing/photos/#{page.photo}.webp").exist?, page.slug if page.photo
    end
  end
end
