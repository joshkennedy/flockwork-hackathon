require "test_helper"

class MarketingPagesTest < ActionDispatch::IntegrationTest
  RENDERED = -> { MarketingPage::ALL.select { |page| page.home? || Rails.root.join("app/views/marketing_pages/#{page.template}.html.erb").exist? } }

  test "registry routes reach the marketing controller" do
    assert_recognizes({ controller: "marketing_pages", action: "show", slug: "pricing" }, pricing_path)
    assert_recognizes({ controller: "marketing_pages", action: "show", slug: "features/sign-ups" }, features_sign_ups_path)
    assert_recognizes({ controller: "marketing_pages", action: "show", slug: "terms" }, terms_path)
  end

  test "an unknown feature is a 404" do
    get "/features/nope"
    assert_response :not_found
  end

  test "signed-in visitors read marketing pages in the public chrome" do
    sign_in_as_leader
    get terms_path
    assert_response :success
    assert_select ".public-header"
    assert_select ".lp-footer"
    assert_select "aside[aria-label=Organization]", count: 0
  end

  test "every page describes itself to search and answer engines" do
    RENDERED.call.each do |page|
      get page.path
      assert_response :success, page.slug
      assert_select "h1", { count: 1 }, page.slug
      assert_select "title", page.title
      assert_select "meta[name=description][content=?]", page.description
      assert_select "link[rel=canonical][href=?]", "http://www.example.com#{page.path == "/" ? "/" : page.path}"
      assert_select "meta[property='og:image']"
      graph = JSON.parse(css_select("script[type='application/ld+json']").first.text)["@graph"]
      assert_equal %w[Organization WebSite], graph.first(2).map { |node| node["@type"] }
      assert_equal "Outpost Labs LLC", graph.first["legalName"]
      faq = graph.find { |node| node["@type"] == "FAQPage" }
      assert_select ".lp-faq-item h3", count: faq["mainEntity"].size if faq
    end
  end

  test "the canonical drops the query string" do
    get terms_path(utm_source: "x")
    assert_select "link[rel=canonical][href=?]", terms_url
  end
end
