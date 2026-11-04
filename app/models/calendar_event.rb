class CalendarEvent
  def initialize(record, url:)
    @record = record
    @url = url
  end

  def to_ical
    raise ArgumentError, "A calendar event needs a date" unless @record.date

    lines = [
      "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Flockwork//Calendar//EN",
      "BEGIN:VEVENT",
      "UID:#{@record.model_name.singular}-#{@record.id}@flockwork",
      "DTSTAMP:#{@record.updated_at.utc.strftime('%Y%m%dT%H%M%SZ')}",
      "SUMMARY:#{escape(title)}",
      "DESCRIPTION:#{escape(@record.project.name)}",
      "URL:#{@url}"
    ]
    if @record.starts_at_time
      lines << "DTSTART:#{timestamp(@record.starts_at_time)}"
      lines << "DTEND:#{timestamp(@record.ends_at_time)}" if @record.is_a?(ScheduleItem) && @record.ends_at_time
    else
      lines << "DTSTART;VALUE=DATE:#{@record.date.strftime('%Y%m%d')}"
      lines << "DTEND;VALUE=DATE:#{(@record.date + 1).strftime('%Y%m%d')}"
    end
    lines << "LOCATION:#{escape(@record.location)}" if @record.is_a?(ScheduleItem) && @record.location.present?
    lines.concat([ "END:VEVENT", "END:VCALENDAR" ]).map { |line| fold(line) }.join("\r\n") + "\r\n"
  end

  private
    def title
      @record.is_a?(Slot) ? @record.label : @record.title
    end

    # Times have no church timezone; preserve the displayed wall time on import.
    def timestamp(time)
      Time.utc(@record.date.year, @record.date.month, @record.date.day, time.hour, time.min, time.sec).strftime("%Y%m%dT%H%M%S")
    end

    def escape(value)
      value.to_s.gsub(/\\|\r\n|\r|\n|;|,/) do |character|
        case character
        when "\r\n", "\r", "\n" then '\n'
        else "\\#{character}"
        end
      end
    end

    def fold(line)
      parts = [ +"" ]
      line.each_char do |character|
        parts << +" " if parts.last.bytesize + character.bytesize > 75
        parts.last << character
      end
      parts.join("\r\n")
    end
end
