require "zlib"

module ApplicationHelper
  # Matches the avatar-hue-N classes and --color-avatar-N tokens in application.css.
  AVATAR_HUES = 10
  AVATAR_SIZES = { sm: "avatar-sm", md: nil, lg: "avatar-lg" }.freeze

  ICON_PATHS = {
    home: "m3 10 9-7 9 7v10H3Z M9 20v-7h6v7",
    tasks: "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z m3 9 3 3 5-6",
    projects: "M3 6a2 2 0 0 1 2-2h5l2 3h7a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z",
    heart: "M12 20 4 12C-2 5 7 0 12 7c5-7 14-2 8 5Z",
    people: "M12 7a3 3 0 1 1-6 0 3 3 0 0 1 6 0 M3 21v-4a6 6 0 0 1 12 0v4 M16 4a3 3 0 0 1 0 6 M18 13c3 0 4 3 4 5v3",
    oversight: "M3 8h7v13H3Z M14 3h7v18h-7Z",
    notifications: "M5 10a7 7 0 0 1 14 0v5l2 3H3l2-3Z M9 21h6",
    lock: "M5 10h14v11H5Z M8 10V7a4 4 0 0 1 8 0v3 M12 14v3",
    mic: "M9 5a3 3 0 0 1 6 0v7a3 3 0 0 1-6 0Z M5 10v2a7 7 0 0 0 14 0v-2 M12 19v3 M8 22h8",
    schedule: "M5 5h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Z M7 3v4 M17 3v4 M3 11h18 M8 15h3",
    budget: "M5 4h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z M3 9h18 M7 15h3 M16 13v4",
    messages: "M3 4h18v13H9l-6 4Z M7 8h10 M7 12h6",
    docs: "M5 3h9l5 5v13H5Z M14 3v6h5 M9 13h6 M9 17h6",
    list: "M9 5h12 M9 12h12 M9 19h12 M3 5h1 M3 12h1 M3 19h1",
    check: "m5 12 4 4L19 6",
    menu: "M4 7h16 M4 12h16 M4 17h16",
    more: "M5 11.2a.8.8 0 1 0 0 1.6.8.8 0 1 0 0-1.6Z M12 11.2a.8.8 0 1 0 0 1.6.8.8 0 1 0 0-1.6Z M19 11.2a.8.8 0 1 0 0 1.6.8.8 0 1 0 0-1.6Z",
    plus: "M12 5v14 M5 12h14",
    sign_out: "M9 3H3v18h6 M9 12h12 m-5-5 5 5-5 5",
    settings: "M4 6h16 M4 12h16 M4 18h16 M15 4v4 M9 10v4 M17 16v4",
    user: "M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z M4 21v-1a6 6 0 0 1 6-6h4a6 6 0 0 1 6 6v1",
    updown: "m7.5 9.5 4.5-4.5 4.5 4.5 M7.5 14.5l4.5 4.5 4.5-4.5"
  }.freeze

  def icon(name, **options)
    tag.svg(viewBox: "0 0 24 24", width: 16, height: 16, fill: "none", stroke: "currentColor",
      "stroke-width": 1.7, "stroke-linecap": "round", "stroke-linejoin": "round",
      aria: { hidden: true }, focusable: false, class: class_names("shrink-0", options[:class])) do
      if name == :kept
        safe_join([
          tag.path(d: "m12 2 3 3 4 1 1 4 2 2-2 3-1 4-4 1-3 2-3-2-4-1-1-4-2-3 2-2 1-4 4-1Z", fill: "currentColor", stroke: "none"),
          tag.path(d: ICON_PATHS.fetch(:check), stroke: "var(--color-ink)")
        ])
      else
        tag.path(d: ICON_PATHS.fetch(name))
      end
    end
  end

  def organization_navigation
    items = [
      [ "Home", home_path, :home ],
      [ "Projects", projects_path, :projects ],
      [ "Get involved", get_involved_path, :heart ]
    ]
    items << [ "People", people_path, :people ] if Policy.can?(Current.person, :manage_people, Current.organization)
    items << [ "Oversight", oversight_path, :oversight ] if Policy.can?(Current.person, :view_oversight, Current.organization)
    items << [ "Notifications", notifications_path, :notifications ]
    items
  end

  # Settings and Profile live in the account menu, not the nav.
  # Only a Person whose email belongs to several Organizations gets the church switcher.
  def other_churches?
    Current.person.email.present? && Person.where(email: Current.person.email).many?
  end

  # First letter of the first and last name ("Maria Lopez" → "ML"); one word gives one letter, a name with no letters gives "?".
  def person_initials(name)
    words = name.to_s.split
    letters = [ words.first, (words.last if words.size > 1) ].compact.filter_map { |word| word[/[[:alpha:]]/] }
    letters.join.upcase.presence || "?"
  end

  # Stable across processes and restarts (String#hash is seeded per process). Email decides, name is the fallback.
  def avatar_hue(person)
    Zlib.crc32((person.email.presence || person.name).to_s.strip.downcase) % AVATAR_HUES
  end

  # Decorative (aria-hidden) when the name sits beside it; label: true names a bare avatar, like the phone top bar.
  def avatar(person, size: :md, label: false)
    tag.span(person_initials(person.name), class: class_names("avatar avatar-person", "avatar-hue-#{avatar_hue(person)}", AVATAR_SIZES.fetch(size)),
      role: ("img" if label), aria: label ? { label: person.name } : { hidden: true })
  end

  # One name in running text: a pill with the avatar flush at its left end. Without a person, the fallback ("Unassigned") shows alone.
  def person_pill(person, fallback: nil)
    return fallback if person.blank?

    tag.span(class: "person-pill") do
      safe_join([ avatar(person, size: :sm), tag.span(person.name, class: "min-w-0 truncate") ])
    end
  end

  # Several people in one pill: an overlapping stack, then the names (or a label that already includes them).
  def people_pill(people, label: people.map(&:name).to_sentence)
    tag.span(class: "person-pill") do
      safe_join([ avatar_stack(people, size: :sm), tag.span(label, class: "min-w-0 truncate") ])
    end
  end

  # Mentions are stored as @[Name](person:ID) in the rich text; each one renders as a Person pill. Only the church's own People resolve.
  def mention_pills(body)
    people = Current.organization.people.where(id: body.to_plain_text.scan(MentionParser::TOKEN_PATTERN).flatten).index_by(&:id)
    body.to_s.gsub(MentionParser::TOKEN_PATTERN) do |token|
      person = people[Regexp.last_match(1).to_i]
      person ? person_pill(person) : token
    end.html_safe
  end

  # Up to three overlapping people, then "+N". The names sit in the text beside it, so the stack is decorative.
  def avatar_stack(people, size: :md, max: 3)
    shown = people.first(max)
    extra = people.size - shown.size
    tag.span(class: "avatar-stack", aria: { hidden: true }) do
      safe_join(shown.map { |person| avatar(person, size: size) } + (extra.positive? ? [ tag.span("+#{extra}", class: class_names("avatar avatar-person text-ink-2", AVATAR_SIZES.fetch(size))) ] : []))
    end
  end

  # The "Manage it" tier of the button grammar: a ⋯ button opening a menu of
  # links and button_tos. Mark destructive items with class "menu-danger".
  # align: :start opens the panel to the right, for a menu at the left edge of a scrolling table.
  def actions_menu(label, align: :end, &items)
    tag.details(class: "actions-menu relative") do
      safe_join([
        tag.summary(icon(:more), class: "btn btn-icon", aria: { label: label }, title: label),
        tag.div(capture(&items), class: class_names("actions-menu-panel popover-in", "actions-menu-panel-start": align == :start))
      ])
    end
  end

  def page_header(title, subtitle: nil, &actions)
    tag.header(class: "page-header") do
      heading = tag.div(class: "min-w-0") do
        safe_join([ tag.h1(title, class: "text-ink"), (tag.p(subtitle, class: "page-subtitle") if subtitle) ].compact)
      end
      actions_html = capture(&actions) if actions
      safe_join([ heading, (tag.div(actions_html, class: "page-actions") if actions_html.present?) ].compact)
    end
  end

  def breadcrumb_label
    return "Planner" if controller_name == "planner_sessions"
    return "Team" if controller_name == "projects" && action_name == "team"
    return "Edit Project" if controller_name == "projects" && action_name == "edit"

    content_for(:title).to_s.split(/ [·—-] /).first
  end

  def navigation_current?(path)
    current_page?(path) || (path != home_path && request.path.start_with?("#{path}/"))
  end

  # The church's mark color: the signed-in Organization, or the Project's on public pages.
  def mark_color
    (@organization || Current.organization)&.mark_color || Organization::DEFAULT_MARK_COLOR
  end

  # Light or dark is chosen per device and kept in a cookie; anything else follows the OS.
  def appearance
    cookies[:appearance].presence_in(%w[light dark]) || "system"
  end

  # Only a church's own color is set inline, so the default mark can brighten in dark mode.
  def mark_color_style
    "--color-mark: #{mark_color}" unless mark_color == Organization::DEFAULT_MARK_COLOR
  end

  def mark_favicon_svg(color)
    # Deep sunlit brightens to sunlit on dark chrome; any other hue already reads on dark.
    lead_dark = color == Organization::DEFAULT_MARK_COLOR ? " .lead { stroke: #F5B000 }" : ""
    <<~SVG.squish
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><style>@media (prefers-color-scheme: dark) { .ink { stroke: #FFFFFF }#{lead_dark} }</style>
      <g fill="none" stroke-linecap="round" stroke-linejoin="round"><path class="lead" d="M8.21 10.54 12 7.66l3.79 2.88" stroke="#{color}" stroke-width="3.22"/>
      <path class="ink" d="M2.5 16.35 5.8 13.85l3.3 2.5M14.9 16.35l3.3-2.5 3.3 2.5" stroke="#141413" stroke-width="2.8"/></g></svg>
    SVG
  end
end
