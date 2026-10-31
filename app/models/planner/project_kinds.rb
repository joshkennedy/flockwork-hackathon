module Planner
  module ProjectKinds
    CHOICES = {
      "meal_train" => {
        name: "Meal train",
        description: "Organize meals for a meal train.",
        prompt: "Help organize a meal train. Build a Sign-up sheet of meals with open roles, without asking for names or private care details."
      },
      "retreat" => {
        name: "Retreat",
        description: "Plan a retreat together.",
        prompt: "Help organize a retreat. Learn the kind of retreat and the work needed, then build a useful plan with open roles."
      },
      "workday" => {
        name: "Workday",
        description: "Organize a shared workday.",
        prompt: "Help organize a workday. Learn the work and resources needed, then build a practical plan with open roles."
      },
      "children_program" => {
        name: "Children’s program",
        description: "Plan a children’s program.",
        prompt: "Help organize a children's program. Plan activities, preparation, supplies, and open volunteer roles. Never ask for children's names or private information."
      },
      "other" => {
        name: "New Project",
        description: "Shape a new Project together.",
        prompt: "Help organize a new Project. First learn what kind of work the Leader wants to organize. Ask about the work, never people's names or private care details."
      }
    }.freeze
  end
end
