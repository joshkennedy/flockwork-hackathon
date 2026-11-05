require "test_helper"

class UploadServingTest < ActionDispatch::IntegrationTest
  test "a rich-text attachment declared as a PDF with HTML bytes is served as an attachment" do
    sign_in_as_volunteer
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("<html><script>alert(1)</script></html>"),
      filename: "fake.pdf",
      content_type: "application/pdf",
      identify: false,
      metadata: { "organization_id" => people(:volunteer).organization_id }
    )

    get rails_blob_path(blob)
    follow_redirect!

    assert_response :success
    assert_match(/\Aattachment/, response.headers["Content-Disposition"])
  end

  test "an image uploaded to a banner or rich text is still served inline" do
    sign_in_as_volunteer
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("banner_small.png").open,
      filename: "banner.png",
      metadata: { "organization_id" => people(:volunteer).organization_id }
    )

    get rails_blob_path(blob)
    follow_redirect!

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_match(/\Ainline/, response.headers["Content-Disposition"])
  end

  test "a doc file declared as PDF with HTML bytes downloads as application/octet-stream" do
    sign_in_as_volunteer
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools | [ "docs" ])
    item = project.doc_items.create!(
      kind: "file",
      title: "Fake PDF",
      author: people(:volunteer),
      file: { io: StringIO.new("<html><script>alert(1)</script></html>"), filename: "fake.pdf", content_type: "application/pdf", identify: false }
    )

    get download_project_doc_item_path(project, item)

    assert_response :success
    assert_equal "application/octet-stream", response.media_type
    assert_match(/\Aattachment/, response.headers["Content-Disposition"])
  end

  test "a doc file of plain text named fake.png downloads as application/octet-stream" do
    sign_in_as_volunteer
    project = projects(:community_meal)
    project.update!(enabled_tools: project.enabled_tools | [ "docs" ])
    item = project.doc_items.create!(
      kind: "file",
      title: "Fake PNG",
      author: people(:volunteer),
      file: { io: StringIO.new("not an image"), filename: "fake.png", content_type: "image/png", identify: false }
    )

    get download_project_doc_item_path(project, item)

    assert_equal "application/octet-stream", response.media_type
  end
end
