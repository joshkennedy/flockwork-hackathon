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

  test "person_initials uses the first letters of the first two names" do
    assert_equal "JK", person_initials("Josh Kennedy")
    assert_equal "M", person_initials("Maria")
    assert_equal "AM", person_initials("Ada Mary Hopper")
  end
end
