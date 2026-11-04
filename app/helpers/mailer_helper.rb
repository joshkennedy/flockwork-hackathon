# Email clients drop <style> blocks and web fonts unevenly, so every email element carries its styles inline.
# Values follow DESIGN.md (Warm Studio); sizes run a step larger than the app because most email is read on phones.
module MailerHelper
  FONT = %("Mona Sans", -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif)

  STYLES = {
    heading: "margin:0 0 12px;font-family:#{FONT};font-size:22px;line-height:28px;font-weight:600;letter-spacing:-0.01em;color:#141413",
    paragraph: "margin:0 0 16px;font-family:#{FONT};font-size:16px;line-height:24px;color:#141413",
    muted: "margin:0 0 12px;font-family:#{FONT};font-size:13px;line-height:18px;color:#5F5E5A",
    link: "color:#141413;text-decoration:underline",
    detail_label: "padding:10px 16px 10px 0;border-top:1px solid #EFEEEB;font-family:#{FONT};font-size:13px;line-height:18px;color:#5F5E5A;white-space:nowrap;vertical-align:top;width:1%",
    detail_value: "padding:10px 0;border-top:1px solid #EFEEEB;font-family:#{FONT};font-size:15px;line-height:21px;color:#141413;vertical-align:top"
  }.freeze

  def mail_heading(text)
    tag.h1(text, style: STYLES[:heading])
  end

  def mail_paragraph(text = nil, &block)
    tag.p(text, style: STYLES[:paragraph], &block)
  end

  def mail_muted(text = nil, &block)
    tag.p(text, style: STYLES[:muted], &block)
  end

  def mail_link(text, url)
    link_to text, url, style: STYLES[:link]
  end

  # A table-cell button, the one form that keeps its fill and radius in Outlook and Gmail alike.
  # DESIGN.md allows one primary button per view, so each email gets at most one.
  def mail_button(text, url)
    tag.table(role: "presentation", cellpadding: 0, cellspacing: 0, border: 0, style: "margin:8px 0 24px") do
      tag.tr do
        tag.td(style: "background:#141413;border-radius:6px") do
          link_to text, url, style: "display:inline-block;padding:12px 20px;font-family:#{FONT};font-size:15px;line-height:20px;font-weight:500;color:#FFFFFF;text-decoration:none;border-radius:6px"
        end
      end
    end
  end

  # Label/value rows split by hairlines; flat on purpose, because DESIGN.md rules out cards inside cards.
  def mail_details(rows)
    rows = rows.compact_blank
    return if rows.empty?

    tag.table(role: "presentation", cellpadding: 0, cellspacing: 0, border: 0, width: "100%", style: "margin:4px 0 20px;border-bottom:1px solid #EFEEEB") do
      safe_join(rows.map { |label, value|
        tag.tr { tag.td(label, style: STYLES[:detail_label]) + tag.td(value, style: STYLES[:detail_value]) }
      })
    end
  end

  def mail_date(date)
    date.strftime(date.year == Date.current.year ? "%A, %B %-d" : "%A, %B %-d, %Y")
  end

  def mail_time(time)
    time.strftime("%-l:%M %p").strip
  end
end
