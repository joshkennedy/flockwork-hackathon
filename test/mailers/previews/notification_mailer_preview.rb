# Preview at /rails/mailers/notification_mailer
# Notifications are built in memory, so opening a preview never writes to the database.
class NotificationMailerPreview < ActionMailer::Preview
  def task_assigned
    task = Task.where.not(due_on: nil).first || Task.first!
    email_for "task_assigned", task, actor: task.project.owner
  end

  def slot_reminder
    slot = Slot.where.not(starts_at_time: nil).first || Slot.first!
    email_for "slot_reminder", slot
  end

  def mention
    comment = sample_comment
    email_for "mention", Mention.new(mentionable: comment, person: comment.author), actor: comment.author
  end

  def followed_reply
    comment = sample_comment
    email_for "followed_reply", comment, actor: comment.author
  end

  def team_departure
    email_for "team_departure", Project.first!
  end

  private
    def sample_comment
      task = Task.first!
      Comment.new(commentable: task, author: task.project.owner, body: "Can you grab the extra tables too?")
    end

    def email_for(kind, notifiable, actor: nil)
      recipient = Person.where.not(email: nil).where.not(id: actor&.id).first!
      notification = Notification.new(kind: kind, notifiable: notifiable, actor: actor, recipient: recipient)
      NotificationMailer.with(notification: notification).notification_email
    end
end
