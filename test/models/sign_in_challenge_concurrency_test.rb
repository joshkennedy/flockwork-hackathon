require "test_helper"

class SignInChallengeConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @organization = organizations(:st_example)
    @project = projects(:community_meal)
  end

  teardown do
    SignInChallenge.delete_all
  end

  test "simultaneous requests for one address stay within its hourly limit and leave one open code" do
    (SignInChallenge::HOURLY_LIMIT - 1).times { issue("nadia@example.com") }

    results = race(3) { issue("nadia@example.com") }

    assert_equal 1, results.count(&:itself)
    assert_equal SignInChallenge::HOURLY_LIMIT, SignInChallenge.where(address: "nadia@example.com").count
    assert_equal 1, SignInChallenge.open.where(address: "nadia@example.com").count
  end

  test "simultaneous texts to different numbers stay within the church's hourly text limit" do
    (SignInChallenge::ORGANIZATION_HOURLY_TEXT_LIMIT - 1).times do |i|
      SignInChallenge.create!(organization: @organization, channel: "sms", address: "+1202555#{format("%04d", 1000 + i)}", expires_at: 15.minutes.from_now)
    end

    results = race(3) { |i| issue("+1303555010#{i}", channel: "sms") }

    assert_equal 1, results.count(&:itself)
    assert_equal SignInChallenge::ORGANIZATION_HOURLY_TEXT_LIMIT, SignInChallenge.where(channel: "sms").count
  end

  private
    def issue(address, channel: "email")
      SignInChallenge.issue(organization: Organization.find(@organization.id), project: @project, channel:, address:)
    end

    # Starts the block on several connections at the same moment and returns each thread's result.
    def race(count)
      ready = Queue.new
      start = Queue.new
      threads = count.times.map do |i|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ready << true
            start.pop
            yield(i)
          end
        end
      end
      count.times { ready.pop }
      count.times { start << true }
      threads.map(&:value)
    end
end
