require "json"
require "vcr"
require "webmock/minitest"

if ENV["VCR_RECORD"] == "1"
  require "dotenv"
  Dotenv.load(Rails.root.join(".env.development.local"))
end

VCR.configure do |config|
  config.cassette_library_dir = Rails.root.join("test/vcr_cassettes")
  config.hook_into :webmock
  config.ignore_localhost = true
  config.ignore_request { |request| URI(request.uri).host == "unix" }
  config.default_cassette_options = {
    record: ENV["VCR_RECORD"] == "1" ? :all : :none
  }
  config.filter_sensitive_data("<PCO_AUTHORIZATION>") do |interaction|
    interaction.request.headers["Authorization"]&.first
  end
  config.filter_sensitive_data("<PCO_APP_ID>") { ENV["PCO_APP_ID"] }
  config.filter_sensitive_data("<PCO_SECRET>") { ENV["PCO_SECRET"] }
  # The sandbox account owner is a real person; cassettes must hold only synthetic People.
  config.before_record do |interaction|
    document = JSON.parse(interaction.response.body)
    owner = document.fetch("data", []).find { |person| person.dig("attributes", "site_administrator") }
    next unless owner

    owner["attributes"].merge!(
      "name" => "Pat Shepherd", "first_name" => "Pat", "last_name" => "Shepherd",
      "login_identifier" => "pat.shepherd@grace.example",
      "avatar" => "https://avatars.planningcenteronline.com/uploads/initials/PS.png",
      "demographic_avatar_url" => "https://avatars.planningcenteronline.com/uploads/initials/PS.png"
    )
    email_ids = owner.dig("relationships", "emails", "data").to_a.pluck("id")
    document.fetch("included", []).each do |resource|
      resource["attributes"]["address"] = "pat.shepherd@grace.example" if resource["type"] == "Email" && email_ids.include?(resource["id"])
    end
    interaction.response.body = JSON.generate(document)
  rescue JSON::ParserError
    nil
  end
end
