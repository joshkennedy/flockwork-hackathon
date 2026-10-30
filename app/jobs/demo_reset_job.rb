class DemoResetJob < ApplicationJob
  def perform
    DemoWorkspace.reset!
  end
end
