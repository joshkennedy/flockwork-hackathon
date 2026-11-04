class WeeklyProjectDigestJob < ApplicationJob
  def perform
    week = Date.current.beginning_of_week.iso8601
    Project.active.joins(:organization).where(organizations: { demo: false }).find_each do |project|
      project.with_lock do
        project.memberships.leader.includes(:person).each do |membership|
          person = membership.person
          next unless ProjectDigestMailer.eligible?(project, person)

          key = "weekly-project-digest/#{project.id}/#{person.id}/#{week}"
          next if Rails.cache.read(key)

          ProjectDigestMailer.weekly(project, person).deliver_now
          Rails.cache.write(key, true, expires_in: 2.weeks)
        end
      end
    end
  end
end
