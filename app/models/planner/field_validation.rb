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
      required_text.each { |name| errors << "#{name.humanize} can’t be blank" unless fields[name].is_a?(String) && fields[name].present? }
      %w[date due_on].each do |name|
        next unless fields[name].present?
        Date.iso8601(fields[name]) if fields[name].is_a?(String)
        errors << "#{name.humanize} needs a real calendar date" unless fields[name].is_a?(String)
      rescue Date::Error
        errors << "#{name.humanize} needs a real calendar date"
      end
      %w[time starts_at ends_at].each do |name|
        errors << "#{name.humanize} needs a time of day" if fields[name].present? && (!fields[name].is_a?(String) || !fields[name].match?(TIME))
      end
      if %w[booking purchase].include?(kind) && fields["estimated_dollars"].present?
        value = BigDecimal(fields["estimated_dollars"].to_s, exception: false)
        errors << "Estimated cost must be 0 or more" unless value&.finite? && value >= 0
      end
      if kind == "enable_tool"
        errors << "Tool must be one from the list" unless fields["tool"].is_a?(String) && Project::TOOLS.include?(fields["tool"])
      end
      if %w[slot slot_run].include?(kind) && fields["claim_prompt"].present?
        prompt = fields["claim_prompt"]
        errors << "Question for people signing up must be text" unless prompt.is_a?(String)
        errors << "Question for people signing up is too long (maximum is 120 characters)" if prompt.is_a?(String) && prompt.length > 120
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
