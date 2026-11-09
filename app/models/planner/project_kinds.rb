module Planner
  module ProjectKinds
    CUSTOM_NAME_PREFIX = /\A(?:
      (?:please\s+)?(?:help\s+)?(?:organize|plan|coordinate|host|run|prepare|create|set\s+up)\s+
      |.+?\s+(?:is|are)\s+(?:organizing|planning|coordinating|hosting|running|preparing)\s+
    )(?:an|a|the)?\s*/ix

    CHOICES = {
      "meal_train" => {
        name: "Meal train",
        date_label: "First meal date",
        description: "Organize meals for a meal train.",
        prompt: "Help organize a meal train. Build a Sign-up sheet of meals with open roles, without asking for names or private care details."
      },
      "retreat" => {
        name: "Retreat",
        date_label: "Retreat date",
        description: "Plan a retreat together.",
        prompt: "Help organize a retreat. Learn the kind of retreat and the work needed, then build a useful plan with open roles."
      },
      "workday" => {
        name: "Workday",
        date_label: "Workday date",
        description: "Organize a shared workday.",
        prompt: "Help organize a workday. Learn the work and resources needed, then build a practical plan with open roles."
      },
      "children_program" => {
        name: "Children’s program",
        date_label: "Program start date",
        description: "Plan a children’s program.",
        prompt: "Help organize a children's program. Plan activities, preparation, supplies, and open volunteer roles. Never ask for children's names or private information."
      },
      "class" => {
        name: "Class",
        date_label: "First class date",
        description: "Plan a class series with teachers, food, and take-home materials.",
        prompt: "Help organize a class series. Ask how many sessions there are and the date of each session, which teaching roles each session needs, whether food or catering is needed, and which curriculum handouts or take-home materials must be prepared. Build open roles without asking for names or private details. Create each session as a schedule_item. Create its teaching role as a slot_run, such as \"Teacher, Session 3,\" and set schedule_item_source_key to that session's source_key."
      },
      "other" => {
        name: "Project",
        date_label: "Start date",
        description: "Shape a new Project together.",
        prompt: "Help organize a new Project. First learn what kind of work the Leader wants to organize. Ask about the work, never people's names or private care details."
      }
    }.freeze

    def self.provisional_name(kind, description: nil)
      return CHOICES.fetch(kind).fetch(:name) unless kind == "other" && description.present?

      name = description.squish.split(/[.!?]/, 2).first.to_s
        .sub(CUSTOM_NAME_PREFIX, "")
        .sub(/\A(?:an|a|the)\s+/i, "")
        .strip
      return CHOICES.fetch(kind).fetch(:name) if name.blank?

      name = name.sub(/\A\p{L}/) { |letter| letter.upcase }
      name.truncate(80, omission: "…")
    end
  end
end
