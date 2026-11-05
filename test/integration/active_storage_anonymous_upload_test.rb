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
      post rails_direct_uploads_path, params: {
        authenticity_token: csrf_token,
        blob: {
          filename: "x.pdf",
          byte_size: payload.bytesize,
          checksum: Digest::MD5.base64digest(payload),
          content_type: "application/pdf",
          metadata: {}
        }
      }
    end

    assert_response :not_found
  ensure
    ActionController::Base.allow_forgery_protection = original_forgery_protection
  end
end
