# Skills are free tags stored lowercase so Postgres array overlap (&&) matches "Driving" and "driving".
# SUGGESTED is the seeded vocabulary offered as checkboxes and sent to the Planner; People's own tags never are.
module Skills
  SUGGESTED = [
    "Cooking", "Driving", "Hospitality", "Childcare", "Teaching", "Music", "Sound and tech", "Photography",
    "Setup and teardown", "Handyman", "Gardening", "Prayer", "Admin", "Design", "First aid", "Translation"
  ].freeze
  MAX_COUNT = 20
  MAX_LENGTH = 40

  module_function

  def normalize(value)
    Array(value).flat_map { |entry| entry.to_s.split(",") }
      .map { |skill| skill.squish.downcase.first(MAX_LENGTH) }
      .compact_blank.uniq.first(MAX_COUNT)
  end

  def label(skill)
    SUGGESTED.find { |suggested| suggested.casecmp?(skill) } || skill.upcase_first
  end

  def suggested_keys = SUGGESTED.map(&:downcase)
end
