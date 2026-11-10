module MarketingHelper
  def marketing_head(page, type: "WebPage", faqs: [], breadcrumbs: [], image: nil, node: {})
    page_url = marketing_url(page)
    organization_id = "#{root_url}#org"
    social_image = image || (page.scene ? "marketing/#{page.scene}-still.webp" : "marketing/hero-still.webp")
    graph = [
      {
        "@type" => "Organization",
        "@id" => organization_id,
        "name" => "Flockwork",
        "legalName" => "Outpost Labs LLC",
        "url" => root_url,
        "logo" => "#{root_url}icon.png",
        "email" => "hello@getflockwork.com"
      },
      {
        "@type" => "WebSite",
        "name" => "Flockwork",
        "url" => root_url,
        "publisher" => { "@id" => organization_id }
      },
      {
        "@type" => type,
        "name" => type == "SoftwareApplication" ? "Flockwork" : page.label,
        "url" => page_url,
        "description" => page.description,
        "publisher" => { "@id" => organization_id }
      }.merge(node)
    ]

    if breadcrumbs.any?
      graph << {
        "@type" => "BreadcrumbList",
        "itemListElement" => breadcrumbs.each_with_index.map do |breadcrumb, index|
          {
            "@type" => "ListItem",
            "position" => index + 1,
            "name" => breadcrumb.label,
            "item" => marketing_url(breadcrumb)
          }
        end
      }
    end

    if faqs.any?
      graph << {
        "@type" => "FAQPage",
        "mainEntity" => faqs.map do |question, answer|
          {
            "@type" => "Question",
            "name" => question,
            "acceptedAnswer" => { "@type" => "Answer", "text" => answer }
          }
        end
      }
    end

    content_for :title, page.title
    content_for :head do
      safe_join([
        tag.meta(name: "description", content: page.description),
        tag.link(rel: "canonical", href: page_url),
        tag.meta(property: "og:type", content: "website"),
        tag.meta(property: "og:site_name", content: "Flockwork"),
        tag.meta(property: "og:title", content: page.title.delete_prefix("Flockwork · ").delete_suffix(" · Flockwork")),
        tag.meta(property: "og:description", content: page.description),
        tag.meta(property: "og:url", content: page_url),
        tag.meta(property: "og:image", content: image_url(social_image)),
        tag.meta(name: "twitter:card", content: "summary_large_image"),
        tag.script({ "@context" => "https://schema.org", "@graph" => graph }.to_json.html_safe, type: "application/ld+json", nonce: content_security_policy_nonce)
      ], "\n".html_safe)
    end

    nil
  end

  def marketing_page?
    controller_name.in?(%w[landing marketing_pages])
  end

  def marketing_url(page)
    page.home? ? root_url : root_url.chomp("/") + page.path
  end
end
