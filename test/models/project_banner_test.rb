require "test_helper"

class ProjectBannerTest < ActiveSupport::TestCase
  setup do
    @project = projects(:community_meal)
    attach_ready_banner(@project)
  end

  test "the wide crop follows the focal point and stays inside the photo" do
    # banner_wide.jpg is 2000x900: narrower than 3:1, so the crop spans the full width and moves vertically.
    @project.banner_focus_y = 0
    assert_equal [ 0, 0, 2000, 667 ], @project.banner_crop(:wide)

    @project.banner_focus_y = 1
    assert_equal [ 0, 233, 2000, 667 ], @project.banner_crop(:wide)
  end

  test "a small photo is flagged so it is shown on a blurred fill instead of upscaled" do
    assert_not @project.banner_small?

    attach_ready_banner(@project, fixture: "banner_small.png", content_type: "image/png")

    assert @project.banner_small?
  end

  test "focal point must sit between 0 and 1" do
    @project.banner_focus_x = 1.2

    assert_not @project.valid?
    assert @project.errors.of_kind?(:banner_focus_x, :less_than_or_equal_to)
  end

  test "a one pixel wide photo never produces a zero-size crop, and its variants process" do
    png = Vips::Image.black(1, 1).write_to_buffer(".png")
    @project.banner.attach(io: StringIO.new(png), filename: "dot.png", content_type: "image/png")
    @project.banner.blob.analyze

    assert_equal [ 0, 0, 1, 1 ], @project.banner_crop(:wide)
    assert_equal [ 0, 0, 1, 1 ], @project.banner_crop(:phone)
    assert_nothing_raised { @project.banner_variants.each(&:processed) }
  end
end
