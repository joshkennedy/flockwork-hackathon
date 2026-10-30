class Mention < ApplicationRecord
  belongs_to :mentionable, polymorphic: true
  belongs_to :person
  has_many :notifications, as: :notifiable, dependent: :destroy

  after_create :notify_person

  private
    def notify_person
      Notifier.notify(
        recipient: person,
        kind: "mention",
        notifiable: self,
        actor: mentionable.author
      )
    end
end
