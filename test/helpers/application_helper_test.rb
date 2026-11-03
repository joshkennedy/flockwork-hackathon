require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "page_header renders the title alone" do
    html = page_header("People")
    assert_dom_equal %(<header class="page-header"><div class="min-w-0"><h1 class="text-ink">People</h1></div></header>), html
  end

  test "page_header renders subtitle and actions" do
    html = page_header("People", subtitle: "Everyone in the directory") { tag.a("Add person", href: "/people/new") }
    assert_includes html, %(<p class="page-subtitle">Everyone in the directory</p>)
    assert_includes html, %(<div class="page-actions"><a href="/people/new">Add person</a></div>)
  end

  test "page_header skips an empty actions block" do
    html = page_header("Notifications") { nil }
    assert_not_includes html, "page-actions"
  end

  test "actions_menu wraps items in a labelled more button" do
    html = actions_menu("Slot actions") { tag.a("Edit slot", href: "/slots/1/edit") }
    assert_dom_equal(%(<details class="actions-menu relative"><summary class="btn btn-icon" aria-label="Slot actions" title="Slot actions">#{icon(:more)}</summary><div class="actions-menu-panel popover-in"><a href="/slots/1/edit">Edit slot</a></div></details>), html)
  end

  test "person_initials uses the first letter of the first and last names" do
    assert_equal "JK", person_initials("Josh Kennedy")
    assert_equal "ML", person_initials("Maria Lopez")
    assert_equal "AH", person_initials("Ada Mary Hopper")
    assert_equal "M", person_initials("Maria")
  end

  test "person_initials handles blanks, punctuation and non-Latin names" do
    assert_equal "?", person_initials(nil)
    assert_equal "?", person_initials("   ")
    assert_equal "?", person_initials("123")
    assert_equal "JK", person_initials("(Josh) Kennedy")
    assert_equal "M", person_initials("123 Maria")
    assert_equal "李", person_initials("李明")
    assert_equal "ÉÅ", person_initials("élodie Ångström")
  end

  test "avatar_hue is the same for the same email, whatever the name" do
    first = Person.new(name: "Maria Lopez", email: "maria@example.com")
    renamed = Person.new(name: "Mary L.", email: "maria@example.com")
    assert_equal avatar_hue(first), avatar_hue(renamed)
    assert_equal Zlib.crc32("maria@example.com") % ApplicationHelper::AVATAR_HUES, avatar_hue(first)
  end

  test "avatar_hue ignores email case" do
    assert_equal avatar_hue(Person.new(name: "A", email: "maria@example.com")),
      avatar_hue(Person.new(name: "A", email: "Maria@Example.com"))
  end

  test "avatar_hue falls back to the name when there is no email" do
    person = Person.new(name: "Maria Lopez", email: nil)
    assert_equal Zlib.crc32("maria lopez") % ApplicationHelper::AVATAR_HUES, avatar_hue(person)
  end

  test "avatar_hue stays inside the palette" do
    hues = (1..200).map { |n| avatar_hue(Person.new(name: "Person #{n}")) }
    assert hues.all? { |hue| hue.between?(0, ApplicationHelper::AVATAR_HUES - 1) }
    assert_operator hues.uniq.size, :>=, 8
  end

  test "avatar is decorative beside a name and labelled when alone" do
    person = Person.new(name: "Maria Lopez", email: "maria@example.com")
    decorative = avatar(person)
    assert_dom_equal %(<span class="avatar avatar-person avatar-hue-#{avatar_hue(person)}" aria-hidden="true">ML</span>), decorative

    labelled = avatar(person, size: :lg, label: true)
    assert_dom_equal %(<span class="avatar avatar-person avatar-hue-#{avatar_hue(person)} avatar-lg" role="img" aria-label="Maria Lopez">ML</span>), labelled
  end

  test "avatar_stack shows up to three people and a count for the rest" do
    people = (1..5).map { |n| Person.new(name: "Person #{n}") }
    html = avatar_stack(people)
    assert_equal 3, html.scan("avatar-hue-").size
    assert_includes html, "+2"
    assert_no_match(/\+\d/, avatar_stack(people.first(3)))
  end

  test "person_pill puts a small avatar and the name in one pill" do
    person = Person.new(name: "Maria Lopez", email: "maria@example.com")
    html = person_pill(person)
    assert_dom_equal %(<span class="person-pill"><span class="avatar avatar-person avatar-hue-#{avatar_hue(person)} avatar-sm" aria-hidden="true">ML</span><span class="min-w-0 truncate">Maria Lopez</span></span>), html
  end

  test "person_pill shows the fallback alone when there is no person" do
    assert_equal "Unassigned", person_pill(nil, fallback: "Unassigned")
    assert_nil person_pill(nil)
  end

  test "mention_pills swaps tokens for pills of this church's People only" do
    leader = people(:leader)
    Current.session = leader.sessions.create!(ip_address: "127.0.0.1", user_agent: "test")
    outsider = organizations(:outsider_church).people.create!(name: "Outside Person")
    body = ActionText::Content.new(%(<div>Hi @[#{leader.name}](person:#{leader.id}), not @[Outside Person](person:#{outsider.id}) or @[Gone](person:0)</div>))

    html = mention_pills(body)

    assert_equal 1, html.scan(%(class="person-pill")).size
    assert_includes html, leader.name
    assert_includes html, "@[Outside Person](person:#{outsider.id})"
    assert_includes html, "@[Gone](person:0)"
  end

  test "people_pill is one pill with the stack and the names, or a label that includes them" do
    people = [ Person.new(name: "Grace Kim"), Person.new(name: "Maria Lopez") ]
    html = people_pill(people)
    assert_includes html, %(class="person-pill")
    assert_includes html, "Grace Kim and Maria Lopez"
    assert_equal 2, html.scan("avatar-hue-").size

    assert_includes people_pill(people, label: "Grace Kim and 2 others signed up"), "Grace Kim and 2 others signed up"
  end
end
