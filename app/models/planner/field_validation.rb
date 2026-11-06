module Planner
  module FieldValidation
    TIME_PATTERN = "([01]\\d|2[0-3]):[0-5]\\d"
    TIME = /\A#{TIME_PATTERN}\z/

    module_function

    def errors(kind, fields)
      errors = []
      required_text = case kind
      when "task", "schedule_item" then [ "title" ]
      when "booking", "purchase" then [ "description" ]
      when "list", "skill" then [ "name" ]
      else []
      end
      required_text.each { |name| errors << "#{name.humanize} is invalid" unless fields[name].is_a?(String) && fields[name].present? }
      %w[date due_on].each do |name|
        next unless fields[name].present?
        Date.iso8601(fields[name]) if fields[name].is_a?(String)
        errors << "#{name.humanize} is invalid" unless fields[name].is_a?(String)
      rescue Date::Error
        errors << "#{name.humanize} is invalid"
      end
      %w[time starts_at ends_at].each do |name|
        errors << "#{name.humanize} is invalid" if fields[name].present? && (!fields[name].is_a?(String) || !fields[name].match?(TIME))
      end
      if %w[booking purchase].include?(kind) && fields["estimated_dollars"].present?
        value = BigDecimal(fields["estimated_dollars"].to_s, exception: false)
        errors << "Estimated cost is invalid" unless value&.finite? && value >= 0
      end
      if kind == "enable_tool"
        errors << "Tool is invalid" unless fields["tool"].is_a?(String) && Project::TOOLS.include?(fields["tool"])
      end
      errors
    end

    def valid_columns?(columns)
      columns.is_a?(Array) && columns.size.between?(1, 20) && columns.all? do |column|
        column.is_a?(Hash) && column["name"].is_a?(String) && column["name"].present? && ListColumn.column_types.key?(column["type"])
      end
    end
  end
end
