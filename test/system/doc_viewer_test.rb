require "application_system_test_case"

class DocViewerSystemTest < ApplicationSystemTestCase
  setup do
    project = Project.create_for(
      creator: people(:grace_leader),
      attributes: {
        name: "Viewer Project",
        description: "Docs to read.",
        starts_on: Date.new(2027, 3, 12),
        ends_on: Date.new(2027, 3, 13),
        enabled_tools: [ "docs" ]
      }
    )
    @project = project
    @item = project.doc_items.create!(
      kind: "file",
      title: "Volunteer Handbook",
      author: people(:grace_leader),
      file: { io: file_fixture("handbook.pdf").open, filename: "handbook.pdf", content_type: "application/pdf" }
    )
  end

  test "opening a PDF doc renders its pages onto canvases under the CSP, with paging, zoom and download" do
    visit new_demo_session_path
    click_on "Explore as Leader"
    assert_selector "[data-signed-in-as]", text: "Maria Lopez"

    visit project_path(@project)
    click_on "Volunteer Handbook"

    assert_selector "[data-controller=doc-viewer] canvas", count: 2
    width = evaluate_script("document.querySelector('[data-doc-viewer-target=pages] canvas').width")
    assert_operator width, :>, 0
    assert_text "Page 1 of 2"

    click_on "Next"
    assert_text "Page 2 of 2"
    click_on "Zoom in"
    assert_text "125%"
    assert_selector "[data-controller=doc-viewer] canvas", count: 2
    assert_selector "a[href='#{download_project_doc_item_path(@project, @item)}']", text: "Download"
  end
end
