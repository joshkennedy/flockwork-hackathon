class CalendarDownloadsController < ApplicationController
  before_action :set_project

  def slot
    slot = @project.slots.find(params[:slot_id])
    raise ActiveRecord::RecordNotFound unless slot.slot_claims.exists?(person: Current.person)

    download(slot)
  end

  def schedule_item
    download(@project.schedule_items.find(params[:schedule_item_id]))
  end

  private
    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def download(record)
      raise ActiveRecord::RecordNotFound unless record.date

      send_data CalendarEvent.new(record, url: project_url(@project)).to_ical,
        filename: "#{record.model_name.singular}-#{record.id}.ics",
        type: "text/calendar; charset=utf-8", disposition: "attachment"
    end
end
