require "json"
require "net/http"
require "set"

module DirectorySources
  class PlanningCenter
    PEOPLE_URL = "https://api.planningcenteronline.com/people/v2/people?include=emails,phone_numbers&per_page=100".freeze
    MAX_PAGES = 50

    def initialize(app_id:, secret:, skills_field_id: nil)
      @app_id = app_id
      @secret = secret
      @skills_field_id = skills_field_id.presence
    end

    def each_person
      return enum_for(:each_person) unless block_given?

      validate_skills_field! if skills_field_id
      next_url = PEOPLE_URL
      seen = Set.new
      pages = 0
      while next_url
        raise Error, "Planning Center returned a repeated page. Nothing was changed." unless seen.add?(next_url)
        pages += 1
        raise Error, "Planning Center returned too many pages. Nothing was changed." if pages > MAX_PAGES
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
      attr_reader :app_id, :secret, :skills_field_id

      def get(url)
        uri = URI(url)
        unless uri.scheme == "https" && uri.host == "api.planningcenteronline.com" && uri.port == 443 && uri.userinfo.nil? && uri.path.start_with?("/people/v2/")
          raise Error, "Planning Center returned an unsafe page link. Nothing was changed."
        end
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
        }.merge(skills_field_id ? skills_for(person.fetch("id")) : {})
      end

      def validate_skills_field!
        unless skills_field_id.to_s.match?(/\A[1-9]\d{0,19}\z/)
          raise Error, "The Skills mapping needs a numeric Planning Center custom field ID. Nothing was changed."
        end
        field = JSON.parse(get("https://api.planningcenteronline.com/people/v2/field_definitions/#{skills_field_id}").body).fetch("data")
        unless field.fetch("type") == "FieldDefinition" && field.fetch("id") == skills_field_id && field.dig("attributes", "data_type") == "string"
          raise Error, "The Skills mapping must use a plain text (string) custom field. Selection and other field types are not supported. Nothing was changed."
        end
      end

      def skills_for(person_id)
        unless person_id.to_s.match?(/\A[1-9]\d*\z/)
          raise Error, "Planning Center returned an invalid Person ID. Nothing was changed."
        end
        query = URI.encode_www_form("where[field_definition_id]" => skills_field_id, "per_page" => 100)
        next_url = "https://api.planningcenteronline.com/people/v2/people/#{person_id}/field_data?#{query}"
        seen = Set.new
        values = []
        pages = 0
        while next_url
          raise Error, "Planning Center returned a repeated page. Nothing was changed." unless seen.add?(next_url)
          pages += 1
          raise Error, "Planning Center returned too many pages. Nothing was changed." if pages > MAX_PAGES
          document = JSON.parse(get(next_url).body)
          document.fetch("data").each do |datum|
            next unless datum.dig("relationships", "field_definition", "data", "id") == skills_field_id
            value = datum.fetch("attributes").fetch("value")
            unless value.nil? || value.is_a?(String)
              raise Error, "The Skills field must contain text labels. Nothing was changed."
            end
            values << value
          end
          next_url = document.dig("links", "next")
        end
        return {} if values.empty?
        raise Error, "Planning Center returned multiple values for the Skills field. Nothing was changed." if values.many?

        skills = Skills.normalize(values.first)
        if skills.any? { |skill| skill.match?(/\A\d+\z/) }
          raise Error, "The Skills field must contain labels, not numeric option IDs. Nothing was changed."
        end
        { skills: skills }
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
