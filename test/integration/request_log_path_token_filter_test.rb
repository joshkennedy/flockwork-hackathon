require "test_helper"

class RequestLogPathTokenFilterTest < ActionDispatch::IntegrationTest
  test "Started request logs omit raw sign-in and invitation path tokens" do
    sign_in_token = people(:leader).generate_token_for(:sign_in)

    invitation = Invitation.create!(
      organization: organizations(:st_example),
      project: projects(:community_meal),
      person: people(:other_volunteer),
      inviter: people(:leader),
      role: :volunteer,
      status: :pending
    )
    invitation_token = invitation.generate_token_for(:access)

    io = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)

    get sign_in_link_path(sign_in_token)
    assert_response :success

    get invitation_path(invitation_token)
    assert_response :success

    log = io.string
    started_lines = log.lines.grep(/Started GET/)

    assert started_lines.any?, "expected a Started GET log line, got:\n#{log}"
    started_lines.each do |line|
      refute_includes line, sign_in_token, line
      refute_includes line, invitation_token, line
    end
  ensure
    Rails.logger = original_logger
  end
end
