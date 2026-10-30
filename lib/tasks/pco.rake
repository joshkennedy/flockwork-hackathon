require "json"
require "net/http"

namespace :pco do
  desc "Seed the owned Planning Center sandbox with synthetic People"
  task seed_sandbox: :environment do
    abort "Refusing to seed Planning Center without PCO_SANDBOX=1." unless ENV["PCO_SANDBOX"] == "1"

    app_id = ENV.fetch("PCO_APP_ID")
    secret = ENV.fetch("PCO_SECRET")
    existing_names = DirectorySources::PlanningCenter.new(app_id:, secret:).each_person.pluck(:name).to_set
    no_email_names = DemoWorkspace::NO_EMAIL_NAMES.first(3)
    available_names = DemoWorkspace::PEOPLE.values.pluck(:name) + DemoWorkspace::DIRECTORY_NAMES
    names = available_names.reject { |name| no_email_names.include?(name) }.first(22) + no_email_names
    created = 0

    names.each_with_index do |name, index|
      if existing_names.include?(name)
        puts "Skipped #{name}."
        next
      end

      first_name, last_name = name.split(" ", 2)
      person = pco_post(
        "https://api.planningcenteronline.com/people/v2/people",
        app_id:,
        secret:,
        data: { type: "Person", attributes: { first_name:, last_name: } }
      )
      person_id = person.dig("data", "id")
      phone = "202-555-01#{index.to_s.rjust(2, "0")}"

      unless no_email_names.include?(name)
        pco_post(
          "https://api.planningcenteronline.com/people/v2/people/#{person_id}/emails",
          app_id:,
          secret:,
          data: {
            type: "Email",
            attributes: { address: "#{name.parameterize(separator: ".")}@grace.example", location: "Home", primary: true }
          }
        )
      end

      pco_post(
        "https://api.planningcenteronline.com/people/v2/people/#{person_id}/phone_numbers",
        app_id:,
        secret:,
        data: { type: "PhoneNumber", attributes: { number: phone, location: "Mobile", primary: true } }
      )
      created += 1
      puts "Created #{name}."
    end

    puts "Planning Center sandbox ready: #{created} created, #{names.length - created} already present."
  end
end

def pco_post(url, app_id:, secret:, data:)
  uri = URI(url)
  request = Net::HTTP::Post.new(uri)
  request.basic_auth(app_id, secret)
  request["Accept"] = "application/json"
  request["Content-Type"] = "application/json"
  request.body = JSON.generate(data:)
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  raise "Planning Center returned HTTP #{response.code}." unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body)
end
