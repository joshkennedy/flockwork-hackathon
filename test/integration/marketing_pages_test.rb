require "test_helper"

class MarketingPagesTest < ActionDispatch::IntegrationTest
  test "Railway hosts redirect to the canonical site except for the healthcheck" do
    host! "web-production-dd06b.up.railway.app"

    get rails_health_check_path
    assert_response :success

    get features_tasks_path, params: { source: "railway" }
    assert_response :moved_permanently
    assert_redirected_to "https://getflockwork.com/features/tasks?source=railway"
  end

  test "public navigation marks the current page and exposes every feature" do
    [ features_path, pricing_path ].each do |path|
      get path
      assert_select ".public-header nav > a[aria-current=page][href=?]", path, count: 1
      assert_select ".public-header nav > a", minimum: 4
      MarketingPage.in_section(:feature).each do |page|
        assert_select ".public-features-panel a[href=?]", page.path, text: /#{Regexp.escape(page.label)}/
      end
      assert_select ".public-features-panel a[href=?]", features_path, text: "All features"
    end
    get features_planner_path
    assert_select ".public-features-panel a[aria-current=page][href=?]", features_planner_path
    assert_select ".public-header nav > a[aria-current=page]", count: 0
    get new_sign_in_request_path
    assert_select ".public-header[data-controller=public-header]", count: 0
    assert_select ".public-features-panel", count: 0
  end

  test "home links to every feature from its marketing content" do
    get root_path
    MarketingPage.in_section(:feature).each do |page|
      assert_select ".marketing a[href=?]", page.path, text: "More about #{page.label.downcase}"
    end
  end

  test "marketing pages load only the marketing JavaScript entry point" do
    get root_path

    assert_select "script[type=module]", text: /import "marketing"/
    assert_select "script[type=module]", text: /import "application"/, count: 0
    assert_select "link[rel=modulepreload]", count: 3
    assert_select "link[rel=modulepreload][href*='pdf']", count: 0
    assert_select "link[rel=modulepreload][href*='trix']", count: 0
  end

  test "feature questions and closing titles fit the feature" do
    MarketingPage.in_section(:feature).each do |page|
      get page.path
      assert_select ".lp-faq h2", "Questions, answered."
      assert_not_includes response.body, "Sign-up questions."
      if page.slug == "features/sign-ups"
        assert_select ".lp-close h2", "Fill the next open spot."
      else
        assert_not_includes response.body, "Fill the next open spot."
        assert_select ".lp-close h2", "Start with one project."
      end
    end
  end

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

  test "robots, sitemap and llms.txt are built from the registry" do
    get "/robots.txt"
    assert_equal "text/plain", response.media_type
    assert_includes response.body, "Sitemap: #{sitemap_url}"
    get "/sitemap.xml"
    MarketingPage::ALL.each { |page| assert_includes response.body, "<loc>http://www.example.com#{page.path}</loc>" }
    assert_not_includes response.body, sign_up_url
    get "/llms.txt"
    MarketingPage::ALL.reject(&:home?).each { |page| assert_includes response.body, "http://www.example.com#{page.path}" }
  end

  test "pages link to a complete web app manifest" do
    get root_path
    assert_select "link[rel=manifest][href=?]", "/manifest.json"

    get "/manifest.json"
    assert_response :success
    assert_equal "application/json", response.media_type
    manifest = JSON.parse(response.body)
    assert_equal "Flockwork", manifest.fetch("name")
    assert_equal "standalone", manifest.fetch("display")
    assert_equal "/", manifest.fetch("scope")
    assert_equal [ "512x512" ], manifest.fetch("icons").map { |icon| icon.fetch("sizes") }.uniq
  end

  test "every marketing page shares the header and footer, and app pages are noindex" do
    get terms_path
    [ features_path, pricing_path, new_demo_session_path, new_sign_in_request_path ].each { |path| assert_select ".public-header nav a[href=?]", path }
    assert_select ".public-header details", count: 0
    assert_select ".public-header a.btn-secondary[href=?]", sign_up_path, text: "Plan Your First Project"
    assert_select ".lp-footer-legal", text: /Outpost Labs LLC/
    assert_select "meta[name=robots]", count: 0
    get new_sign_in_request_path
    assert_select "meta[name=robots][content=noindex]"
  end

  test "sign in guides invited people without revealing account existence" do
    get new_sign_in_request_path

    assert_select "p", "Use the email your church leader added. For privacy, the next screen looks the same even when an email isn’t found."
  end

  test "pricing says free during beta and offers nothing it can't back" do
    get pricing_path
    assert_select "h1", "Free during beta."
    assert_select ".lp-plan a.btn-primary[href=?]", sign_up_path, text: "Plan Your First Project"
    assert_select ".marketing a.btn-primary", count: 2
    assert_select ".lp-faq-item h3", count: 5
    offer = JSON.parse(css_select("script[type='application/ld+json']").first.text)["@graph"].find { |node| node["@type"] == "SoftwareApplication" }["offers"]
    assert_equal "0", offer["price"]
    assert_not_includes response.body, "aggregateRating"
    get root_path
    assert_select ".lp-hero .lp-reassure", "Free during beta. No card."
  end

  test "about and contact name the company and the address" do
    get about_path
    assert_includes response.body, "Outpost Labs LLC"
    get contact_path
    assert_select "a[href=?]", "mailto:hello@getflockwork.com"
    assert_select "form", count: 0
  end

  test "every feature page answers its question first and links onward" do
    MarketingPage.in_section(:feature).each do |page|
      get page.path
      assert_select "nav.lp-crumbs a[href=?]", features_path
      answer = css_select("p.lp-answer").first.text
      words = answer.split.size
      assert words.between?(40, 60), "#{page.slug} answer is #{words} words"
      assert_includes answer, "Flockwork"
      assert_select ".lp-row", count: 3
      assert_select "figure.lp-photo img[alt]"
      assert_select ".lp-related a", minimum: 2
      assert_select ".marketing a.btn-primary", count: 1
      types = JSON.parse(css_select("script[type='application/ld+json']").first.text)["@graph"].map { |node| node["@type"] }
      assert_equal %w[Organization WebSite WebPage BreadcrumbList FAQPage], types
    end
  end

  test "the features index lists all seven and names the other tools" do
    get features_path
    MarketingPage.in_section(:feature).each { |page| assert_select ".marketing a[href=?]", page.path, text: /#{page.label}/ }
    assert_select "h2", "Also in every project."
    [ "Messages", "Docs & Files", "List" ].each { |tool| assert_select ".marketing", text: /#{tool}/ }
  end

  test "every registry page now renders and no two feature pages share an answer" do
    assert_equal MarketingPage::ALL.size, RENDERED.call.size
    answers = MarketingPage.in_section(:feature).map { |page| get(page.path); css_select("p.lp-answer").first.text }
    assert_equal answers.size, answers.uniq.size
  end
end
