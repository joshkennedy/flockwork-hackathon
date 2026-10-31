# Signs in through the real flow: request a link, read it from the delivered email, consume it.
module SignInHelpers
  def sign_in_as(person_or_name)
    person = person_or_name.is_a?(Symbol) ? people(person_or_name) : person_or_name
    token = request_sign_in_link(person)

    post sign_in_link_path(token)
    assert_redirected_to home_path
    person
  end

  def sign_in_as_admin = sign_in_as(:admin)
  def sign_in_as_leader = sign_in_as(:leader)
  def sign_in_as_volunteer = sign_in_as(:volunteer)
  def sign_in_as_outsider = sign_in_as(:outsider)

  def request_sign_in_link(person)
    perform_enqueued_jobs do
      post sign_in_requests_path, params: { email: person.email }
    end

    ActionMailer::Base.deliveries.last.body.encoded[%r{/sign_in/(\S+)}, 1]
  end
end
