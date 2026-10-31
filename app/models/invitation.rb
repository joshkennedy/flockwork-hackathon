class Invitation < ApplicationRecord
  include OrganizationScoped

  belongs_to :project
  belongs_to :person
  belongs_to :inviter, class_name: "Person"
  has_many :notifications, as: :notifiable, dependent: :destroy

  enum :role, { leader: 0, volunteer: 1 }
  enum :status, { pending: 0, accepted: 1, declined: 2 }

  generates_token_for :access do
    status
  end

  validates :person_id, uniqueness: {
    scope: :project_id,
    conditions: -> { where(status: :pending) },
    message: "already has a pending Invitation"
  }, if: :pending?
  validate :people_and_project_belong_to_organization, on: :create
  validate :person_can_be_invited, on: :create

  def accept!
    with_lock do
      unless pending?
        errors.add(:status, "has already been answered")
        raise ActiveRecord::RecordInvalid.new(self)
      end

      project.memberships.create!(person: person, role: role)
      update!(status: :accepted, responded_at: Time.current)
    end
  end

  def decline!
    with_lock do
      unless pending?
        errors.add(:status, "has already been answered")
        raise ActiveRecord::RecordInvalid.new(self)
      end

      update!(status: :declined, responded_at: Time.current)
    end
  end

  private
    def people_and_project_belong_to_organization
      return if [ project, person, inviter ].all? { |record| record&.organization_id == organization_id }

      errors.add(:base, "Project, invitee, and inviter must belong to the Organization")
    end

    def person_can_be_invited
      errors.add(:person, "has no email and can't be invited") if person&.email.blank?
      errors.add(:person, "is already a Team member") if project&.memberships&.exists?(person: person)
    end
end
