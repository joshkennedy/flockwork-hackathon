require "test_helper"
require "digest"

class ActiveStorageAnonymousUploadTest < ActionDispatch::IntegrationTest
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

  private
    def post_direct_upload(payload, csrf_token:)
      post rails_direct_uploads_path,
        params: {
          blob: {
            filename: "x.pdf",
            byte_size: payload.bytesize,
            checksum: Digest::MD5.base64digest(payload),
            content_type: "application/pdf"
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
