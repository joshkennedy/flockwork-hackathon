require "test_helper"

class PersonTest < ActiveSupport::TestCase
  test "normalizes the email to lowercase without surrounding spaces" do
    person = Person.create!(organization: organizations(:st_example), name: "New Person", email: "  New.Person@Example.ORG ")

    assert_equal "new.person@example.org", person.email
  end

  test "stores a blank email as nil so people without email never collide" do
    person = Person.create!(organization: organizations(:st_example), name: "No Email", email: "   ")

    assert_nil person.email
    assert_not person.can_sign_in?
  end

  test "allows the same email in two organizations but not twice in one" do
    duplicate = Person.new(organization: organizations(:st_example), name: "Twin", email: people(:admin).email.upcase)

    assert_not duplicate.valid?
    assert Person.new(organization: organizations(:outsider_church), name: "Twin", email: people(:admin).email).valid?
  end

  test "a sign-in token works once: the second use is refused" do
    person = people(:leader)
    token = person.generate_token_for(:sign_in)

    assert_equal person, Person.sign_in_with_token(token)
    assert_nil Person.sign_in_with_token(token)
  end

  test "a sign-in token stops working after 15 minutes" do
    person = people(:volunteer)
    token = person.generate_token_for(:sign_in)

    travel 15.minutes + 1.second do
      assert_nil Person.sign_in_with_token(token)
    end
  end

  test "using one link invalidates links issued before it" do
    person = people(:other_leader)
    first = person.generate_token_for(:sign_in)
    second = person.generate_token_for(:sign_in)

    assert Person.sign_in_with_token(second)
    assert_nil Person.sign_in_with_token(first)
  end

  test "the last Admin cannot be demoted when they are the only Admin" do
    admin = people(:admin)

    assert_not admin.update(admin: false)
    assert_includes admin.errors[:admin], "cannot be removed from the last Admin in the Organization"
  end
end
