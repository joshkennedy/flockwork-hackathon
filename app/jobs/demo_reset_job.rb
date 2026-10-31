class DemoResetJob < ApplicationJob
  def perform
    DemoOrganization.reset!
  end
end
