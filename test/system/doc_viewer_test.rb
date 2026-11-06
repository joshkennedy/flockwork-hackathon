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

  test "a scanned PDF with a JPEG2000 image decodes through the vendored wasm decoder" do
    @project.doc_items.create!(
      kind: "file",
      title: "Scanned Flyer",
      author: people(:grace_leader),
      file: { io: file_fixture("scan.pdf").open, filename: "scan.pdf", content_type: "application/pdf" }
    )
    visit new_demo_session_path
    click_on "Explore as Leader"
    assert_selector "[data-signed-in-as]", text: "Maria Lopez"

    visit project_path(@project)
    click_on "Scanned Flyer"

    assert_selector "[data-controller=doc-viewer] canvas", count: 1
    # The image is a top-red to bottom-blue gradient; an undecoded image would leave the page white.
    pixels = evaluate_script(<<~JS)
      (() => {
        const canvas = document.querySelector("[data-doc-viewer-target=pages] canvas")
        const context = canvas.getContext("2d")
        const sample = (y) => Array.from(context.getImageData(canvas.width / 2, y, 1, 1).data)
        return [sample(4), sample(canvas.height - 5)]
      })()
    JS
    top, bottom = pixels
    assert_operator top[0], :>, top[2] + 60
    assert_operator bottom[2], :>, bottom[0] + 60
  end

  test "the decoder and font assets the viewer points at are served" do
    visit new_demo_session_path
    click_on "Explore as Leader"
    assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    visit project_path(@project)
    click_on "Volunteer Handbook"
    assert_selector "[data-controller=doc-viewer] canvas", count: 2

    base = find("[data-controller=doc-viewer]")["data-doc-viewer-assets-value"]
    statuses = evaluate_async_script(<<~JS, base)
      const [base, done] = arguments
      Promise.all(["wasm/openjpeg.wasm", "wasm/jbig2.wasm", "standard_fonts/FoxitSerif.pfb", "standard_fonts/LiberationSans-Regular.ttf", "cmaps/90ms-RKSJ-H.bcmap"]
        .map((path) => fetch(`${base}/${path}`).then((response) => response.status))).then(done)
    JS
    assert_equal [ 200, 200, 200, 200, 200 ], statuses
  end

  test "the PDF scripting engine assets are unavailable while the color decoder remains served" do
    visit new_demo_session_path
    click_on "Explore as Leader"
    assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    visit project_path(@project)
    click_on "Volunteer Handbook"
    assert_selector "[data-controller=doc-viewer] canvas", count: 2

    base = find("[data-controller=doc-viewer]")["data-doc-viewer-assets-value"]
    statuses = evaluate_async_script(<<~JS, base)
      const [base, done] = arguments
      Promise.all(["wasm/quickjs-eval.wasm", "wasm/quickjs-eval.js", "wasm/qcms_bg.wasm"]
        .map((path) => fetch(`${base}/${path}`).then((response) => response.status))).then(done)
    JS
    assert_equal [ 404, 404, 200 ], statuses
  end

  test "zooming keeps the current page in view" do
    visit new_demo_session_path
    click_on "Explore as Leader"
    assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    visit project_path(@project)
    click_on "Volunteer Handbook"
    assert_selector "[data-controller=doc-viewer] canvas", count: 2

    click_on "Next"
    # At 300% the two pages are taller than the viewer, so the page has to be scrolled to.
    8.times { click_on "Zoom in" }
    assert_text "300%"
    assert_selector "[data-controller=doc-viewer] canvas", count: 2
    assert_text "Page 2 of 2"

    # Zoom re-renders every page; the swap lands after the counter updates.
    page.document.synchronize do
      visible = evaluate_script(<<~JS)
        (() => {
          const container = document.querySelector("[data-doc-viewer-target=pages]").getBoundingClientRect()
          const canvas = document.querySelectorAll("[data-doc-viewer-target=pages] canvas")[1]?.getBoundingClientRect()
          return !!canvas && canvas.top >= container.top - 1 && canvas.bottom <= container.bottom + 1
        })()
      JS
      raise Capybara::ExpectationNotMet, "page 2 is not fully inside the viewer" unless visible
    end
  end
end
