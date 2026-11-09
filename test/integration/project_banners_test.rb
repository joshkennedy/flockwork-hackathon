require "test_helper"

class ProjectBannersTest < ActionDispatch::IntegrationTest
  test "a leader uploads a banner that starts centered and queues a focus suggestion" do
    sign_in_as_leader
    project = projects(:community_meal)
    upload = fixture_file_upload("banner_wide.jpg", "image/jpeg")

    assert_enqueued_with(job: ProjectBannerFocusJob) do
      patch project_banner_path(project), params: { project: { banner: upload } }
    end

    assert_redirected_to project_path(project)
    project.reload
    assert project.banner.attached?
    assert_equal project.organization_id, project.banner.blob.metadata["organization_id"]
    assert_equal 0.5, project.banner_focus_x
    assert_equal 0.5, project.banner_focus_y
  end

  test "a banner signed id string is rejected without attaching it" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("banner_wide.jpg").open,
      filename: "banner.jpg",
      content_type: "image/jpeg",
      metadata: { "organization_id" => organizations(:outsider_church).id }
    )
    sign_in_as_leader
    project = projects(:community_meal)

    assert_no_difference "ActiveStorage::Attachment.count" do
      patch project_banner_path(project), params: { project: { banner: blob.signed_id } }
    end

    assert_response :unprocessable_content
    assert_not project.reload.banner.attached?
  end

  test "an upload is judged by its bytes, so a renamed text file is refused" do
    sign_in_as_leader
    project = projects(:community_meal)

    patch project_banner_path(project), params: { project: { banner: fixture_file_upload("sample_upload.txt", "image/jpeg") } }

    assert_redirected_to project_path(project)
    assert_match "must be a JPEG, PNG, WebP, or HEIC image", flash[:alert]
    assert_not project.reload.banner.attached?
  end

  test "an oversized replacement leaves the existing banner attached" do
    sign_in_as_leader
    project = attach_banner!(projects(:community_meal))
    original_blob_id = project.banner.blob_id
    file = Tempfile.new([ "oversized-replacement", ".png" ], binmode: true)
    file.write(png_bytes_with_declared_dimensions(16_000, 16_000, template: file_fixture("banner_small.png").read))
    file.rewind

    patch project_banner_path(project), params: { project: { banner: Rack::Test::UploadedFile.new(file.path, "image/png") } }

    assert_redirected_to project_path(project)
    assert_match "must not exceed", flash[:alert]
    project.reload
    assert project.banner.attached?
    assert_equal original_blob_id, project.banner.blob_id
  ensure
    file&.close!
  end

  test "a PNG whose header declares oversized dimensions is refused" do
    sign_in_as_leader
    project = projects(:community_meal)
    file = Tempfile.new([ "oversized-header", ".png" ], binmode: true)
    file.write(png_bytes_with_declared_dimensions(16_000, 16_000, template: file_fixture("banner_small.png").read))
    file.rewind

    patch project_banner_path(project), params: { project: { banner: Rack::Test::UploadedFile.new(file.path, "image/png") } }

    assert_redirected_to project_path(project)
    assert_match "must not exceed", flash[:alert]
    assert_not project.reload.banner.attached?
  ensure
    file&.close!
  end

  test "an image over 10 MB is refused" do
    sign_in_as_leader
    project = projects(:community_meal)
    file = Tempfile.new([ "too-big", ".png" ], binmode: true)
    file.write("\x89PNG\r\n\x1A\n".b + "\0".b * (Project::BANNER_MAX_BYTES + 1))
    file.rewind

    patch project_banner_path(project), params: { project: { banner: Rack::Test::UploadedFile.new(file.path, "image/png") } }

    assert_match "must be 10 MB or smaller", flash[:alert]
    assert_not project.reload.banner.attached?
  ensure
    file&.close!
  end

  test "an 11 MB upload with valid dimensions is refused without creating a blob" do
    sign_in_as_leader
    project = projects(:community_meal)
    file = Tempfile.new([ "eleven-megabyte", ".png" ], binmode: true)
    header = png_bytes_with_declared_dimensions(800, 400, template: file_fixture("banner_small.png").read)
    file.write(header)
    file.write("\0".b * (11.megabytes - header.bytesize))
    file.rewind

    assert_no_difference "ActiveStorage::Blob.count" do
      patch project_banner_path(project), params: { project: { banner: Rack::Test::UploadedFile.new(file.path, "image/png") } }
    end

    assert_redirected_to project_path(project)
    assert_match "must be 10 MB or smaller", flash[:alert]
    assert_not project.reload.banner.attached?
  ensure
    file&.close!
  end

  test "a non-image upload named banner.png is refused without creating a blob" do
    sign_in_as_leader
    project = projects(:community_meal)
    file = Tempfile.new([ "banner", ".png" ], binmode: true)
    file.write("plain text, not an image")
    file.rewind

    assert_no_difference "ActiveStorage::Blob.count" do
      patch project_banner_path(project), params: { project: { banner: Rack::Test::UploadedFile.new(file.path, "image/png", original_filename: "banner.png") } }
    end

    assert_redirected_to project_path(project)
    assert_match "must be a JPEG, PNG, WebP, or HEIC image", flash[:alert]
    assert_not project.reload.banner.attached?
  ensure
    file&.close!
  end

  test "people who cannot edit the Project get not found for every banner change" do
    project = projects(:community_meal)
    sign_in_as_volunteer

    patch project_banner_path(project), params: { project: { banner_focus_x: "0.2" } }
    assert_response :not_found

    delete project_banner_path(project)
    assert_response :not_found
  end

  test "a leader sets the focal point and alt text, and an out-of-range focus is refused" do
    sign_in_as_leader
    project = attach_banner!(projects(:community_meal))

    patch project_banner_path(project), params: { project: { banner_focus_x: "0.2", banner_focus_y: "0.8", banner_alt_text: "Volunteers stacking chairs" } }
    project.reload
    assert_in_delta 0.2, project.banner_focus_x
    assert_in_delta 0.8, project.banner_focus_y
    assert project.banner_focus_manual?
    assert_equal "Volunteers stacking chairs", project.banner_alt_text

    patch project_banner_path(project), params: { project: { banner_focus_x: "1.5" } }
    assert_match "couldn't be saved", flash[:alert]
    assert_in_delta 0.2, project.reload.banner_focus_x
  end

  test "a focal point save keeps the alt text, and an alt text save keeps the focal point" do
    sign_in_as_leader
    project = attach_banner!(projects(:community_meal))

    patch project_banner_path(project), params: { project: { banner_alt_text: "Chairs in rows" } }
    project.reload
    assert_equal "Chairs in rows", project.banner_alt_text
    assert_not project.banner_focus_manual?

    patch project_banner_path(project), params: { project: { banner_focus_x: "0.3", banner_focus_y: "0.6" } }
    project.reload
    assert_in_delta 0.3, project.banner_focus_x
    assert_equal "Chairs in rows", project.banner_alt_text
    assert project.banner_focus_manual?

    patch project_banner_path(project), params: { project: { banner_alt_text: "" } }
    project.reload
    assert_nil project.banner_alt_text
    assert_in_delta 0.3, project.banner_focus_x
  end

  test "the Project page keeps banner controls on the photo, not in a disclosure below it" do
    sign_in_as_leader
    project = attach_banner!(projects(:community_meal))

    get project_path(project)

    assert_select "figure[data-controller~=banner-focus] button", text: "Reposition"
    assert_select "figure[data-controller~=banner-focus] button", text: "Remove"
    assert_select "[data-banner-focus-target=edit] input[name='project[banner_focus_x]']"
    assert_select "#banner-alt-popover input[name='project[banner_alt_text]']"
    assert_select "details summary", text: /focal point/, count: 0
  end

  test "a Project with no banner offers the add dropzone to editors" do
    sign_in_as_leader

    get project_path(projects(:community_meal))

    assert_select "[data-controller~='banner-upload'] input[type=file][name='project[banner]']"
    assert_match "Add a banner image", response.body
  end

  test "removing the banner purges it and resets focus and alt text" do
    sign_in_as_leader
    project = attach_banner!(projects(:community_meal))
    patch project_banner_path(project), params: { project: { banner_focus_x: "0.1", banner_alt_text: "Chairs" } }

    delete project_banner_path(project)

    project.reload
    assert_not project.banner.attached?
    assert_equal 0.5, project.banner_focus_x
    assert_nil project.banner_alt_text
    assert_not project.banner_focus_manual?
  end

  test "the public Project page shows the banner with its alt text" do
    project = attach_banner!(projects(:community_meal))
    project.enable_public_link!

    get public_project_path(project.public_token)

    assert_response :success
    assert_match "alt=\"#{project.name} banner\"", response.body
    assert_select "figure[data-controller]", count: 0
    assert_no_match "Reposition", response.body
  end

  test "an HEIC upload that cannot be decoded is refused with a clear error" do
    sign_in_as_leader
    project = projects(:community_meal)
    file = Tempfile.new([ "broken", ".heic" ], binmode: true)
    file.write("\x00\x00\x00\x18ftypheic\x00\x00\x00\x00mif1heic".b + "garbage".b * 50)
    file.rewind

    patch project_banner_path(project), params: { project: { banner: Rack::Test::UploadedFile.new(file.path, "image/heic") } }

    assert_redirected_to project_path(project)
    assert_equal "The banner couldn't be saved: Banner couldn't be read as an image. Try a JPEG or PNG.", flash[:alert]
    assert_not project.reload.banner.attached?
  ensure
    file&.close!
  end

  test "a readable HEIC upload is accepted" do
    sign_in_as_leader
    project = projects(:community_meal)
    file = Tempfile.new([ "photo", ".heic" ], binmode: true)
    file.write(Vips::Image.black(64, 64).heifsave_buffer)
    file.rewind

    patch project_banner_path(project), params: { project: { banner: Rack::Test::UploadedFile.new(file.path, "image/heic") } }

    assert_redirected_to project_path(project)
    assert_nil flash[:alert]
    assert_equal 64, project.reload.banner.blob.metadata["width"]
  ensure
    file&.close!
  end

  test "an AI alt text suggestion prefills the field, and saving it confirms it" do
    sign_in_as_leader
    project = attach_banner!(projects(:community_meal))
    project.banner.blob.update!(metadata: project.banner.blob.metadata.merge("alt_suggestion" => "Chairs in a hall"))

    get project_path(project)
    assert_select "#banner-alt-popover input[name='project[banner_alt_text]'][value='Chairs in a hall']"
    assert_select "#banner-alt-popover", text: /Suggested by AI/
    assert_select "figure img[alt='#{project.name} banner']"

    patch project_banner_path(project), params: { project: { banner_alt_text: "Chairs in a hall" } }

    project.reload
    assert_equal "Chairs in a hall", project.banner_alt_text
    assert_nil project.banner_alt_suggestion
    get project_path(project)
    assert_select "figure img[alt='Chairs in a hall']"
    assert_select "#banner-alt-popover", text: /Suggested by AI/, count: 0
  end

  test "an unconfirmed suggestion is not shown as alt text on the public page" do
    project = attach_banner!(projects(:community_meal))
    project.banner.blob.update!(metadata: project.banner.blob.metadata.merge("alt_suggestion" => "Chairs in a hall"))
    project.enable_public_link!

    get public_project_path(project.public_token)

    assert_match "alt=\"#{project.name} banner\"", response.body
    assert_no_match "Chairs in a hall", response.body
  end

  private
    def png_bytes_with_declared_dimensions(width, height, template:)
      bytes = template.dup.force_encoding(Encoding::BINARY)
      offset = 8
      while offset + 12 <= bytes.bytesize
        length = bytes[offset, 4].unpack1("N")
        type = bytes[offset + 4, 4]
        if type == "IHDR"
          bytes[offset + 8, 4] = [ width ].pack("N")
          bytes[offset + 12, 4] = [ height ].pack("N")
          chunk = bytes[offset + 4, 4 + length]
          bytes[offset + 8 + length, 4] = [ Zlib.crc32(chunk) ].pack("N")
          break
        end
        offset += 12 + length
      end
      bytes
    end

    def attach_banner!(project)
      attach_ready_banner(project)
    end
end
