class ProjectRecurrence < ApplicationRecord
  belongs_to :project
  belongs_to :creator, class_name: "Person"
  has_many :project_occurrences, dependent: :destroy

  enum :frequency, { weekly: "weekly", monthly: "monthly" }, validate: true
  validates :project_id, uniqueness: true
  validates :anchor_on, presence: true
  validate :creator_can_duplicate

  def generate_upcoming(today: Date.current)
    with_lock do
      return unless enabled? && project.reload.active? && !project.organization.demo?
      return unless Policy.can?(creator.reload, :duplicate, project)

      upcoming_dates(today).each do |date|
        next if project_occurrences.exists?(on: date)

        duplicate = ProjectDuplicate.new(source: project, start_on: date, by: creator)
        duplicate.name = project.name
        copy = duplicate.call
        project_occurrences.create!(project: copy, on: date)
      end
    end
  end

  def upcoming_dates(today)
    return [] unless anchor_on && frequency.present?

    index = if weekly?
      [ ((today - anchor_on).to_i / 7), 1 ].max
    else
      [ (today.year * 12 + today.month) - (anchor_on.year * 12 + anchor_on.month), 1 ].max
    end
    dates = []
    loop do
      date = weekly? ? anchor_on + index.weeks : anchor_on >> index
      break if date > today + 7
      dates << date if date >= today
      index += 1
    end
    dates
  end

  private
    def creator_can_duplicate
      return if project && creator && Policy.can?(creator, :duplicate, project)

      errors.add(:creator, "The person who set this up is no longer a Leader or Admin. Ask a Leader to save it again.")
    end
end
