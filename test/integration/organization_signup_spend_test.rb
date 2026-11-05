require "test_helper"
require_relative "../support/method_stubs"

class OrganizationSignupSpendTest < ActionDispatch::IntegrationTest
  include MethodStubs

  test "anonymous sign-up is bounded per IP" do
    store = ActiveSupport::Cache::MemoryStore.new

    stub_method(OrganizationsController.cache_store, :increment, ->(*args, **kwargs) { store.increment(*args, **kwargs) }) do
      5.times do |index|
        assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
          post organizations_path, params: {
            church_name: "Church #{index}",
            your_name: "Creator #{index}",
            email: "creator-#{index}@example.test"
          }
        end
        assert_response :redirect
      end
      assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
        assert_no_difference [ "Organization.count", "Person.count" ] do
          post organizations_path, params: {
            church_name: "Church blocked",
            your_name: "Blocked Creator",
            email: "blocked@example.test"
          }
        end
      end
      assert_response :too_many_requests
    end
  end
end
