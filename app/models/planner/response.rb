module Planner
  Response = Data.define(:card, :finished, :added, :removed_ids) do
    def validate!
      raise ArgumentError, "Invalid Planner completion state" unless [ true, false ].include?(finished)
      raise ArgumentError, "Invalid Planner Suggestions" unless added.is_a?(Array) && added.all? { |item| item.is_a?(Hash) }
      raise ArgumentError, "Invalid removed Suggestions" unless removed_ids.is_a?(Array) && removed_ids.all? { |id| id.is_a?(String) }
      raise ArgumentError, "Finished Planner responses must have no card" unless finished == card.nil?
      if card
        values = card.to_h.stringify_keys
        options = values["options"]
        unless values["question"].is_a?(String) && values["question"].strip.present? &&
            options.is_a?(Array) && options.size.between?(3, 5) && options.all? { |option| option.is_a?(String) && option.strip.present? }
          raise ArgumentError, "Invalid Planner question"
        end
      end
      self
    end
  end
end
