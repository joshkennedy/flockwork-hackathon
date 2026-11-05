require "test_helper"
require "digest"
require_relative "../support/method_stubs"

class ActiveStorageAnonymousUploadTest < ActionDispatch::IntegrationTest
  include MethodStubs

  test "an anonymous person cannot create a direct upload" do
    original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    payload = "%PDF-1.4\n".b.ljust(1.kilobyte, "0")

    get new_sign_in_request_path
    csrf_token = response.parsed_body.at_css("meta[name=csrf-token]")["content"]

    assert_no_difference "ActiveStorage::Blob.unattached.count" do
      post_direct_upload(payload, csrf_token:)
    end

    assert_response :unauthorized
  ensure
    ActionController::Base.allow_forgery_protection = original_forgery_protection
  end

  test "a signed-in person can create a direct upload" do
    sign_in_as_volunteer
    original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    payload = "%PDF-1.4\n".b.ljust(1.kilobyte, "0")

    get home_path
    csrf_token = response.parsed_body.at_css("meta[name=csrf-token]")["content"]

    assert_difference "ActiveStorage::Blob.unattached.count", 1 do
      post_direct_upload(payload, csrf_token:)
    end

    assert_response :success
  ensure
    ActionController::Base.allow_forgery_protection = original_forgery_protection
  end

  test "a direct upload is owned by the uploader's church and embeds in its Message" do
    person = sign_in_as_volunteer
    original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    payload = file_fixture("banner_small.png").binread

    get home_path
    csrf_token = response.parsed_body.at_css("meta[name=csrf-token]")["content"]
    post_direct_upload(payload, csrf_token:, filename: "banner.png", content_type: "image/png")

    assert_response :success
    upload_response = response.parsed_body
    blob = ActiveStorage::Blob.find_signed!(upload_response.fetch("signed_id"))
    assert_equal person.organization_id, blob.metadata["organization_id"]

    direct_upload = upload_response.fetch("direct_upload")
    put URI.parse(direct_upload.fetch("url")).request_uri,
      params: payload,
      headers: direct_upload.fetch("headers")
    assert_response :no_content

    ActionController::Base.allow_forgery_protection = original_forgery_protection

    project = projects(:community_meal)
    post project_messages_path(project), params: {
      message: {
        body: %(<div>Same church image</div><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>)
      }
    }

    assert_redirected_to project_path(project)
    message = project.messages.order(:id).last!
    assert_equal [ blob.id ], message.body.embeds.map(&:blob_id)

    get project_path(project)

    assert_response :success
    assert_match "Same church image", response.body
    assert_match "banner.png", response.body
  ensure
    ActionController::Base.allow_forgery_protection = original_forgery_protection
  end

  test "a direct upload claiming image/png with HTML bytes is not served inline once embedded" do
    sign_in_as_volunteer
    original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    payload = "<html><script>alert(1)</script></html>"

    get home_path
    csrf_token = response.parsed_body.at_css("meta[name=csrf-token]")["content"]
    post_direct_upload(payload, csrf_token:, filename: "evil.png", content_type: "image/png")
    upload_response = response.parsed_body
    blob = ActiveStorage::Blob.find_signed!(upload_response.fetch("signed_id"))
    direct_upload = upload_response.fetch("direct_upload")
    put URI.parse(direct_upload.fetch("url")).request_uri, params: payload, headers: direct_upload.fetch("headers")
    ActionController::Base.allow_forgery_protection = original_forgery_protection

    project = projects(:community_meal)
    post project_messages_path(project), params: {
      message: { body: %(<div>Hi</div><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>) }
    }
    assert_redirected_to project_path(project)

    get rails_blob_path(blob)
    follow_redirect!

    assert_response :success
    assert_not_equal "image/png", response.media_type
    assert_match(/\Aattachment/, response.headers["Content-Disposition"])
  ensure
    ActionController::Base.allow_forgery_protection = original_forgery_protection
  end

  test "a demo volunteer is limited to 30 direct uploads per hour" do
    post demo_session_path(role: "volunteer")
    original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    payload = "%PDF-1.4\n".b.ljust(1.kilobyte, "0")
    store = ActiveSupport::Cache::MemoryStore.new
    increment = ->(*args, **kwargs) { store.increment(*args, **kwargs) }

    get home_path
    csrf_token = response.parsed_body.at_css("meta[name=csrf-token]")["content"]

    stub_method(ActiveStorage::DirectUploadsController.cache_store, :increment, increment) do
      30.times do
        post_direct_upload(payload, csrf_token:)
        assert_response :success
      end

      assert_no_difference "ActiveStorage::Blob.unattached.count" do
        post_direct_upload(payload, csrf_token:)
      end
      assert_response :too_many_requests
    end
  ensure
    ActionController::Base.allow_forgery_protection = original_forgery_protection
  end

  test "a direct upload over 10 MB is rejected before its blob is created" do
    sign_in_as_volunteer
    original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    payload = "%PDF-1.4\n".b.ljust(1.kilobyte, "0")

    get home_path
    csrf_token = response.parsed_body.at_css("meta[name=csrf-token]")["content"]

    assert_no_difference "ActiveStorage::Blob.unattached.count" do
      post_direct_upload(payload, csrf_token:, byte_size: 11.megabytes)
    end
    assert_response :unprocessable_content
  ensure
    ActionController::Base.allow_forgery_protection = original_forgery_protection
  end

  private
    def post_direct_upload(payload, csrf_token:, byte_size: payload.bytesize, filename: "x.pdf", content_type: "application/pdf")
      post rails_direct_uploads_path,
        params: {
          blob: {
            filename:,
            byte_size:,
            checksum: Digest::MD5.base64digest(payload),
            content_type:
          }
        }.to_json,
        headers: {
          "Accept" => "application/json",
          "Content-Type" => "application/json",
          "X-CSRF-Token" => csrf_token,
          "X-Requested-With" => "XMLHttpRequest"
        }
    end
end
