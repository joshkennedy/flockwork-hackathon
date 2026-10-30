require "json"
require "net/http"

module DirectorySources
  class PlanningCenter < Base
    PEOPLE_URL = "https://api.planningcenteronline.com/people/v2/people?include=emails,phone_numbers&per_page=100".freeze

    def initialize(app_id:, secret:)
      @app_id = app_id
      @secret = secret
    end

    def each_person
      return enum_for(:each_person) unless block_given?

      next_url = PEOPLE_URL
      while next_url
        response = get(next_url)
        document = JSON.parse(response.body)
        included = document.fetch("included", []).index_by { |resource| [ resource.fetch("type"), resource.fetch("id") ] }

        document.fetch("data").each do |person|
          yield person_hash(person, included)
        end

        next_url = document.dig("links", "next")
      end
    rescue JSON::ParserError, KeyError, TypeError, URI::InvalidURIError,
      EOFError, SocketError, SystemCallError, Timeout::Error, Net::ProtocolError, OpenSSL::SSL::SSLError
      raise Error, "Couldn't reach Planning Center. Nothing was changed."
    end

    private
      attr_reader :app_id, :secret

      def get(url)
        uri = URI(url)
        request = Net::HTTP::Get.new(uri)
        request.basic_auth(app_id, secret)

        response = Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: 10,
          read_timeout: 30
        ) { |http| http.request(request) }

        return response if response.is_a?(Net::HTTPSuccess)
        raise Error, "Planning Center didn't accept those credentials." if response.code.in?(%w[401 403])

        raise Error, "Couldn't reach Planning Center. Nothing was changed."
      end

      def person_hash(person, included)
        attributes = person.fetch("attributes")
        {
          external_id: person.fetch("id"),
          name: attributes["name"].presence || [ attributes["first_name"], attributes["last_name"] ].compact.join(" "),
          email: contact_value(person, included, "emails", "Email", "address"),
          phone: contact_value(person, included, "phone_numbers", "PhoneNumber", "number")
        }
      end

      def contact_value(person, included, relationship_name, type, attribute_name)
        contacts = person.dig("relationships", relationship_name, "data").to_a.filter_map do |reference|
          included[[ type, reference.fetch("id") ]]
        end
        contact = contacts.find { |resource| resource.dig("attributes", "primary") } || contacts.first
        contact&.dig("attributes", attribute_name)
      end
  end
end
