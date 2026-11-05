require "test_helper"

class DocItemsTest < ActionDispatch::IntegrationTest
  test "a Volunteer creates and edits a document with body text on the project page" do
    sign_in_as_volunteer
    project = enable_docs_tool!(projects(:community_meal))

    assert_difference "DocItem.count", 1 do
      post project_doc_items_path(project), params: {
        doc_item: {
          kind: "document",
          title: "Prep Notes",
          body: "Chop vegetables before 4 PM."
        }
      }
    end

    item = project.doc_items.find_by!(title: "Prep Notes")
    assert_redirected_to project_path(project)
    follow_redirect!
    assert_match "Chop vegetables before 4 PM.", response.body
    assert_match "Vic Volunteer", response.body

    patch project_doc_item_path(project, item), params: {
      doc_item: {
        kind: "document",
        title: "Prep Notes",
        body: "Chop vegetables before 3 PM."
      }
    }

    assert_redirected_to project_path(project)
    follow_redirect!
    assert_match "Chop vegetables before 3 PM.", response.body
    assert_no_match "Chop vegetables before 4 PM.", response.body
  end

  test "a Volunteer uploads a file and downloads it through the authorized route" do
    sign_in_as_volunteer
    project = enable_docs_tool!(projects(:community_meal))
    upload = fixture_file_upload("sample_upload.txt", "text/plain")

    assert_difference "DocItem.count", 1 do
      post project_doc_items_path(project), params: {
        doc_item: {
          kind: "file",
          title: "Volunteer Handbook",
          file: upload
        }
      }
    end

    item = project.doc_items.find_by!(title: "Volunteer Handbook")
    assert_redirected_to project_path(project)
    assert_equal project.organization_id, item.file.blob.metadata["organization_id"]

    get download_project_doc_item_path(project, item)

    assert_response :success
    assert_equal "Flockwork sample upload file.\n", response.body
  end

  test "an admin cannot attach another church's blob by signed id" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("sample_upload.txt").open,
      filename: "sample_upload.txt",
      content_type: "text/plain",
      metadata: { "organization_id" => organizations(:st_example).id }
    )
    sign_in_as_outsider
    project = enable_docs_tool!(projects(:outsider_project))

    assert_no_difference [ "DocItem.count", "ActiveStorage::Attachment.count" ] do
      post project_doc_items_path(project), params: {
        doc_item: {
          kind: "file",
          title: "Foreign file",
          file: blob.signed_id
        }
      }
    end

    assert_response :unprocessable_content
    assert_not project.doc_items.exists?(title: "Foreign file")
  end

  test "an admin cannot embed another church's blob in a document" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("banner_small.png").open,
      filename: "banner.png",
      content_type: "image/png",
      metadata: { "organization_id" => organizations(:st_example).id }
    )
    sign_in_as_outsider
    project = enable_docs_tool!(projects(:outsider_project))

    assert_no_difference [ "DocItem.count", "ActiveStorage::Attachment.count" ] do
      post project_doc_items_path(project), params: {
        doc_item: {
          kind: "document",
          title: "Foreign image",
          body: %(<div>Foreign image</div><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>)
        }
      }
    end

    assert_response :unprocessable_content
    assert_not project.doc_items.exists?(title: "Foreign image")
  end

  test "a Volunteer adds links and PCO hosts show a badge" do
    sign_in_as_volunteer
    project = enable_docs_tool!(projects(:community_meal))

    post project_doc_items_path(project), params: {
      doc_item: {
        kind: "link",
        title: "PCO Registration",
        url: "https://grace.planningcenteronline.com/registrations/events/123"
      }
    }

    post project_doc_items_path(project), params: {
      doc_item: {
        kind: "link",
        title: "External Reference",
        url: "https://example.com"
      }
    }

    get project_path(project)

    assert_response :success
    assert_select "span", text: "PCO", count: 1
    assert_match "https://grace.planningcenteronline.com/registrations/events/123", response.body
    assert_match "https://example.com", response.body
    # Trix embeds URL templates (":signed_id"); only a real signed blob URL would leak a file.
    assert_no_match %r{/rails/active_storage/(blobs|disk|representations)/(redirect/|proxy/)?(?!:signed_id)[A-Za-z0-9=_-]{20,}}, response.body
  end

  test "a non-member gets 404 on the file download route" do
    sign_in_as_volunteer
    project = enable_docs_tool!(projects(:community_meal))
    upload = fixture_file_upload("sample_upload.txt", "text/plain")

    post project_doc_items_path(project), params: {
      doc_item: { kind: "file", title: "Private File", file: upload }
    }

    item = project.doc_items.find_by!(title: "Private File")

    sign_in_as_outsider

    get download_project_doc_item_path(project, item)

    assert_response :not_found
  end

  test "a Volunteer can delete their own doc item but not another author's item" do
    sign_in_as_leader
    project = enable_docs_tool!(projects(:community_meal))

    post project_doc_items_path(project), params: {
      doc_item: {
        kind: "document",
        title: "Leader Notes",
        body: "Leader-only context."
      }
    }

    leader_item = project.doc_items.find_by!(title: "Leader Notes")

    sign_in_as_volunteer

    post project_doc_items_path(project), params: {
      doc_item: {
        kind: "document",
        title: "Volunteer Notes",
        body: "Volunteer context."
      }
    }

    volunteer_item = project.doc_items.find_by!(title: "Volunteer Notes")

    assert_difference "DocItem.count", -1 do
      delete project_doc_item_path(project, volunteer_item)
    end

    assert_redirected_to project_path(project)

    delete project_doc_item_path(project, leader_item)

    assert_response :not_found
  end

  test "a Volunteer cannot edit a Leader-authored doc but the author and Leaders can" do
    sign_in_as_leader
    project = enable_docs_tool!(projects(:community_meal))

    post project_doc_items_path(project), params: {
      doc_item: {
        kind: "document",
        title: "Leader Run Sheet",
        body: "Original leader text."
      }
    }

    item = project.doc_items.find_by!(title: "Leader Run Sheet")

    sign_in_as_volunteer

    patch project_doc_item_path(project, item), params: {
      doc_item: {
        kind: "document",
        title: "Leader Run Sheet",
        body: "Volunteer tamper attempt."
      }
    }

    assert_response :not_found
    assert_equal "Original leader text.", item.reload.body.to_plain_text

    sign_in_as_leader

    patch project_doc_item_path(project, item), params: {
      doc_item: {
        kind: "document",
        title: "Leader Run Sheet",
        body: "Leader revision."
      }
    }

    assert_redirected_to project_path(project)
    assert_equal "Leader revision.", item.reload.body.to_plain_text
  end

  test "a removed author on an open team project cannot update or destroy their doc" do
    sign_in_as_volunteer
    project = enable_docs_tool!(projects(:community_meal))
    project.update!(open_team: true)

    post project_doc_items_path(project), params: {
      doc_item: {
        kind: "document",
        title: "Open Team Notes",
        body: "Original volunteer text."
      }
    }

    item = project.doc_items.find_by!(title: "Open Team Notes")

    sign_in_as_leader
    membership = project.memberships.find_by!(person: people(:volunteer))

    assert_difference "Membership.count", -1 do
      delete project_membership_path(project, membership)
    end

    sign_in_as_volunteer

    patch project_doc_item_path(project, item), params: {
      doc_item: {
        kind: "document",
        title: "Open Team Notes",
        body: "Tamper after removal."
      }
    }

    assert_response :not_found
    assert_equal "Original volunteer text.", item.reload.body.to_plain_text

    assert_no_difference "DocItem.count" do
      delete project_doc_item_path(project, item)
    end

    assert_response :not_found
  end

  test "a Leader can delete another member's doc item" do
    sign_in_as_volunteer
    project = enable_docs_tool!(projects(:community_meal))

    post project_doc_items_path(project), params: {
      doc_item: {
        kind: "document",
        title: "Temporary Note",
        body: "Remove me."
      }
    }

    item = project.doc_items.find_by!(title: "Temporary Note")

    sign_in_as_leader

    assert_difference "DocItem.count", -1 do
      delete project_doc_item_path(project, item)
    end

    assert_redirected_to project_path(project)
  end

  private
    def enable_docs_tool!(project)
      project.update!(enabled_tools: project.enabled_tools + [ "docs" ])
      project
    end
end
