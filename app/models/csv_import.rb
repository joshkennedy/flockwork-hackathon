require "csv"

class CsvImport
  Result = Data.define(:created_count, :updated_count, :rejected_rows, :fatal_error)

  MalformedFile = Class.new(StandardError)
  TooLarge = Class.new(StandardError)

  MAX_BYTES = 1.megabyte
  MAX_ROWS = 5_000
  TOO_LARGE_MESSAGE = "That CSV is too large. Keep it under 1 MB and 5,000 rows, or split it into smaller files."

  def initialize(organization, file_content)
    @organization = organization
    @file_content = file_content
  end

  def call
    ActiveRecord::Base.transaction do
      table = parse_table!
      import_rows(table)
    end
  rescue MalformedFile
    Result.new(0, 0, [], "That file isn't a CSV with a name column.")
  rescue TooLarge
    Result.new(0, 0, [], TOO_LARGE_MESSAGE)
  end

  private
    def parse_table!
      raise TooLarge if @file_content.bytesize > MAX_BYTES

      table = CSV.parse(utf8_content, headers: true, header_converters: ->(header) { header&.delete_prefix("\uFEFF")&.strip&.downcase })
      raise MalformedFile unless table.headers&.include?("name")
      raise TooLarge if table.size > MAX_ROWS

      table
    rescue CSV::MalformedCSVError
      raise MalformedFile
    end

    def utf8_content
      content = @file_content.to_s.dup
      content.force_encoding(Encoding::UTF_8)
      raise MalformedFile unless content.valid_encoding?

      content.delete_prefix("\uFEFF")
    end

    def import_rows(table)
      created_count = 0
      updated_count = 0
      rejected_rows = []

      table.each_with_index do |row, index|
        line_number = index + 2
        outcome = import_row(row)

        case outcome
        in [ :created ] then created_count += 1
        in [ :updated ] then updated_count += 1
        in [ :rejected, reason ] then rejected_rows << [ line_number, reason ]
        end
      end

      Result.new(created_count, updated_count, rejected_rows, nil)
    end

    def import_row(row)
      name = row["name"]&.strip
      return [ :rejected, "Name is missing" ] if name.blank?

      email = row["email"]
      phone = row["phone"]&.strip.presence
      normalized_email = email.to_s.strip.downcase.presence
      person = @organization.people.find_by(email: normalized_email) if normalized_email

      skills = row.headers.include?("skills") ? { skills: Skills.normalize(row["skills"]) } : {}

      if person
        person.assign_attributes(name:, **skills)
        person.phone = phone if phone
        return [ :updated ] if person.save

        [ :rejected, person.errors.full_messages.to_sentence ]
      else
        person = @organization.people.build(name:, email:, phone:, **skills)
        return [ :created ] if person.save

        [ :rejected, person.errors.full_messages.to_sentence ]
      end
    end
end
