module Planner
  class NameRedactor
    def initialize(organization)
      @organization = organization
    end

    # A name like "The Alvarez Family" or "Dr. Ruth Park" must not turn every "the" or "dr" into [name].
    LEADING_WORDS = %w[the a an mr mrs ms miss dr rev pastor].freeze

    def call(text)
      names = organization.people.pluck(:name).flat_map do |name|
        [ name, name.split.find { |word| !LEADING_WORDS.include?(word.downcase.delete(".")) } ]
      end.compact_blank.uniq.sort_by { |name| -name.length }
      return text if names.empty?

      pattern = names.map { |name| Regexp.escape(name) }.join("|")
      text.gsub(Regexp.new("(?<![\\p{L}\\p{N}])(?:#{pattern})(?![\\p{L}\\p{N}])", Regexp::IGNORECASE), "[name]")
    end

    private
      attr_reader :organization
  end
end
