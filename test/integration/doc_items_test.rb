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

    get download_project_doc_item_path(project, item)

    assert_response :success
    assert_equal "Flockwork sample upload file.\n", response.body
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
    assert_no_match "/rails/active_storage", response.body
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
