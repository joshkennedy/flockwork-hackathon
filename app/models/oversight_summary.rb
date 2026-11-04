# One plain sentence per Oversight card, built from counts and dates only.
class OversightSummary
  class << self
    def facts_for(person, last_check_in: nil)
      since = person.memberships.joins(:project).merge(Project.active).minimum(:created_at)
      {
        "serving_load" => Oversight.serving_load(person),
        "serving_since" => since&.to_date&.iso8601,
        "last_check_in_on" => last_check_in&.on&.iso8601
      }
    end

    def line(_person, facts)
      template(facts)
    end

    def template(facts)
      load = facts["serving_load"].to_i
      since = parse_date(facts["serving_since"])
      last = parse_date(facts["last_check_in_on"])

      sentence = +"Serving on #{load} #{"Active Project".pluralize(load)}"
      sentence << " since #{since.strftime("%B")}#{" #{since.year}" unless since.year == Date.current.year}" if since
      sentence << (last ? ", last check-in #{last.strftime("%b %-d")}" : ", no check-in logged")
      "#{sentence}."
    end

    private
      def parse_date(value)
        Date.iso8601(value) if value.present?
      end
  end
end
