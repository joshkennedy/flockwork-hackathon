namespace :banners do
  desc "Queue variant generation for every Project banner that is not ready to show"
  task prepare: :environment do
    queued = 0
    Project.unscoped.with_attached_banner.find_each do |project|
      next unless project.banner.attached? && !project.banner_ready?

      ProjectBannerVariantsJob.perform_later(project)
      queued += 1
    end
    puts "Queued banner variants for #{queued} Projects."
  end
end
