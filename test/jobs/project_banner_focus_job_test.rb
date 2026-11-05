require "test_helper"

class ProjectBannerFocusJobTest < ActiveJob::TestCase
  setup do
    @project = projects(:community_meal)
    @project.banner.attach(io: file_fixture("banner_wide.jpg").open, filename: "banner.jpg", content_type: "image/jpeg")
    @blob_id = @project.reload.banner.blob_id
    @original_vision = ProjectBannerVision.method(:call)
  end

  teardown do
    ProjectBannerVision.define_singleton_method(:call, @original_vision)
  end

  test "a provider error leaves the banner centered with no alt text" do
    stub_vision -> { raise "provider timed out" }

    ProjectBannerFocusJob.perform_now(@project, @blob_id)

    @project.reload
    assert_equal 0.5, @project.banner_focus_x
    assert_equal 0.5, @project.banner_focus_y
    assert_nil @project.banner_alt_text
  end

  test "a suggestion sets the focal point and keeps the alt text as an unconfirmed suggestion" do
    stub_vision({ focus_x: 0.25, focus_y: 0.7, alt: "A sign-up table under a tree" })

    ProjectBannerFocusJob.perform_now(@project, @blob_id)

    @project.reload
    assert_in_delta 0.25, @project.banner_focus_x
    assert_in_delta 0.7, @project.banner_focus_y
    assert_nil @project.banner_alt_text
    assert_equal "A sign-up table under a tree", @project.banner_alt_suggestion
  end

  test "a focal point the person already set is kept, and confirmed alt text is never replaced by a suggestion" do
    @project.update!(banner_focus_x: 0.9, banner_focus_y: 0.1, banner_focus_manual: true, banner_alt_text: "Our chairs")
    stub_vision({ focus_x: 0.2, focus_y: 0.2, alt: "Chairs" })

    ProjectBannerFocusJob.perform_now(@project, @blob_id)

    @project.reload
    assert_in_delta 0.9, @project.banner_focus_x
    assert_in_delta 0.1, @project.banner_focus_y
    assert_equal "Our chairs", @project.banner_alt_text
  end

  test "without an OpenRouter key the suggestion is skipped" do
    key = ENV.delete("OPENROUTER_API_KEY")

    assert_nil @original_vision.call(@project.banner.blob)
  ensure
    ENV["OPENROUTER_API_KEY"] = key if key
  end

  private
    def stub_vision(result)
      ProjectBannerVision.define_singleton_method(:call) { |_blob| result.respond_to?(:call) ? result.call : result }
    end
end
