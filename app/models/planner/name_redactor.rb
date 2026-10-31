module Planner
  class NameRedactor
    def initialize(organization)
      @organization = organization
    end

    def call(text)
      names = organization.people.pluck(:name).flat_map do |name|
        [ name, name.split.first ]
      end.compact_blank.uniq.sort_by { |name| -name.length }
      return text if names.empty?

      pattern = names.map { |name| Regexp.escape(name) }.join("|")
      text.gsub(Regexp.new("(?<![\\p{L}\\p{N}])(?:#{pattern})(?![\\p{L}\\p{N}])", Regexp::IGNORECASE), "[name]")
    end

    private
      attr_reader :organization
  end
end
