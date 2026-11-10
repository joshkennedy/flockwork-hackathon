require "test_helper"

class RequestLogPathTokenFilterTest < ActionDispatch::IntegrationTest
  test "request logs filter free text and phone numbers" do
    sign_in_as_leader
    body = "Private message body 8472"
    phone = "+12025558472"
    io = StringIO.new
    original_logger = Rails.logger
    original_controller_logger = ActionController::Base.logger
    logger = ActiveSupport::Logger.new(io)
    Rails.logger = logger
    ActionController::Base.logger = logger

    post project_messages_path(projects(:community_meal)), params: { message: { body: } }
    patch profile_path, params: { person: { phone: } }

    log = io.string
    refute_includes log, body
    refute_includes log, phone
    assert_operator log.scan("[FILTERED]").size, :>=, 2
  ensure
    Rails.logger = original_logger
    ActionController::Base.logger = original_controller_logger
  end

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

    get "/invitations//#{invitation_token}"
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
