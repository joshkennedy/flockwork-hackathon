require "application_system_test_case"

class ProjectBannerSystemTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @project = Project.create_for(
      creator: people(:grace_leader),
      attributes: {
        name: "Banner System Project",
        description: "Photos for the banner.",
        starts_on: Date.new(2027, 3, 12),
        ends_on: Date.new(2027, 3, 13),
        enabled_tools: []
      }
    )
    attach_ready_banner(@project)
    @project.reload
  end

  test "a Leader repositions the banner live with arrow keys and saves the focal point" do
    sign_in_as_leader_in_browser
    visit project_path(@project)

    hover_banner
    click_on "Reposition"
    assert_selector "figure[data-repositioning]"
    layer = find("[data-banner-focus-target=layer]")
    layer.send_keys(:right, :right, :right)
    assert_equal "0.560", find("[data-banner-focus-target=x]", visible: :all).value

    click_on "Save"

    assert_text "Banner System Project"
    @project.reload
    assert_in_delta 0.56, @project.banner_focus_x, 0.001
    assert @project.banner_focus_manual?
  end

  test "Escape cancels a reposition and leaves the saved focal point alone" do
    sign_in_as_leader_in_browser
    visit project_path(@project)

    hover_banner
    click_on "Reposition"
    find("[data-banner-focus-target=layer]").send_keys(:left, :escape)

    assert_no_selector "figure[data-repositioning]"
    assert_equal 0.5, @project.reload.banner_focus_x
    assert_not @project.banner_focus_manual?
  end

  test "a Leader replaces the banner photo from the banner, which resets its focal point" do
    @project.update!(banner_focus_x: 0.2, banner_focus_manual: true)
    ProjectBannerVariantsJob.perform_now(@project)
    previous_blob_id = @project.banner.blob_id
    sign_in_as_leader_in_browser
    visit project_path(@project)

    find("input[type=file][name='project[banner]']", visible: :all).set(file_fixture("banner_small.png").to_s)

    assert_selector ".tst-viewport [role=status]", text: "Uploaded banner_small.png", visible: :all
    assert_text "This photo can't be shown yet."
    perform_enqueued_jobs only: ProjectBannerFocusJob
    ProjectBannerVariantsJob.perform_now(@project.reload)
    visit project_path(@project)

    assert_selector "input[name='project[banner_focus_x]'][value='0.5']", visible: :all
    @project.reload
    assert_not_equal previous_blob_id, @project.banner.blob_id
    assert_not @project.banner_focus_manual?
  end

  test "a Leader edits the optional alt text from the banner popover" do
    sign_in_as_leader_in_browser
    visit project_path(@project)

    hover_banner
    click_on "Alt Text"
    fill_in "Alt text", with: "Volunteers stacking chairs"
    click_on "Save Alt Text"

    assert_selector "figure img[alt='Volunteers stacking chairs']", visible: :all
    assert_equal "Volunteers stacking chairs", @project.reload.banner_alt_text
    assert_equal 0.5, @project.banner_focus_x
  end

  private
    # The toolbar fades in on hover, the way a pointer reaches it.
    def hover_banner
      find("figure[data-controller]").hover
    end

    def sign_in_as_leader_in_browser
      visit new_demo_session_path
      click_on "Explore as Leader"
      assert_selector "[data-signed-in-as]", text: "Maria Lopez"
    end
end
