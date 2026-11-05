require "test_helper"

class BannerVariantDecodingTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:community_meal)
    @original_vision = ProjectBannerVision.method(:call)
    ProjectBannerVision.define_singleton_method(:call) { |_blob| nil }
  end

  teardown do
    ProjectBannerVision.define_singleton_method(:call, @original_vision)
  end

  test "a public page never analyzes or decodes a banner that is not stored yet" do
    @project.banner.attach(io: file_fixture("banner_wide.jpg").open, filename: "banner.jpg", content_type: "image/jpeg")
    @project.enable_public_link!

    assert_no_difference "ActiveStorage::VariantRecord.count" do
      get public_project_path(@project.public_token)
    end

    assert_response :success
    assert_not @project.banner.blob.reload.analyzed?
    assert_select "picture img", false
    assert_select "p", text: "This photo can't be shown yet.", count: 0
  end

  test "after the upload jobs run the public page links stored variants and fetching them decodes nothing" do
    sign_in_as_leader
    patch project_banner_path(@project), params: { project: { banner: fixture_file_upload("banner_wide.jpg", "image/jpeg") } }
    perform_enqueued_jobs # the focus job, which then queues the variants job
    perform_enqueued_jobs
    @project.reload.enable_public_link!

    get public_project_path(@project.public_token)
    sources = css_select("picture source, picture img").flat_map { |node| [ node["src"], node["srcset"] ] }.compact

    assert_equal 2, sources.size
    assert_no_difference "ActiveStorage::VariantRecord.count" do
      sources.each do |source|
        get source
        assert_response :redirect
      end
    end
  end

  test "a banner upload is analyzed once and queues no analyze job" do
    sign_in_as_leader

    assert_no_enqueued_jobs only: ActiveStorage::AnalyzeJob do
      patch project_banner_path(@project), params: { project: { banner: fixture_file_upload("banner_wide.jpg", "image/jpeg") } }
    end

    assert @project.reload.banner.blob.analyzed?
  end

  test "a variant that fails is remembered and the page shows no banner instead of retrying" do
    attach_ready_banner(@project)
    @project.update!(banner_focus_y: 0.1)
    @project.banner.blob.service.delete(@project.banner.blob.key)
    @project.enable_public_link!

    ProjectBannerVariantsJob.perform_now(@project)

    assert @project.banner.blob.reload.metadata["variants_failed"]
    get public_project_path(@project.public_token)
    assert_response :success
    assert_select "picture img", false
  end

  test "rotating the public link stores variants for the new banner copy" do
    attach_ready_banner(@project)

    perform_enqueued_jobs { @project.enable_public_link! && @project.reset_public_link! }

    assert @project.reload.banner_ready?
  end
end
