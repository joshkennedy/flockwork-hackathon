class DirectorySync
  def initialize(organization, source)
    @organization = organization
    @source = source
  end

  def call
    counts = { created: 0, updated: 0, unchanged: 0, skipped_email_changes: [] }

    organization.transaction do
      source.each_person do |attributes|
        person = find_person(attributes)
        # An Admin removed this person on purpose; a sync must not quietly bring them back.
        next counts[:unchanged] += 1 unless person.active?

        new_record = person.new_record?
        if (skipped_email_change = skipped_email_change_for(person, attributes.fetch(:email)))
          counts[:skipped_email_changes] << skipped_email_change
        end
        person.assign_attributes(
          name: attributes.fetch(:name),
          email: protected_email?(person) ? person.email : attributes.fetch(:email),
          phone: attributes.fetch(:phone),
          external_source: "planning_center",
          external_id: attributes.fetch(:external_id)
        )

        person.skills = Skills.normalize(attributes[:skills]) if attributes.key?(:skills)

        if new_record
          person.save!
          counts[:created] += 1
        elsif person.changed?
          person.save!
          counts[:updated] += 1
        else
          counts[:unchanged] += 1
        end
      end
    end

    counts
  end

  private
    attr_reader :organization, :source

    def find_person(attributes)
      organization.people.find_by(
        external_source: "planning_center",
        external_id: attributes.fetch(:external_id)
      ) || adoptable_person(attributes) || organization.people.build
    end

    def adoptable_person(attributes)
      email = attributes.fetch(:email)
      organization.people.find_by(email:, external_id: nil) if email.present?
    end

    def protected_email?(person)
      person.persisted? && (person.admin? || person.last_signed_in_at.present? || person.sessions.exists?)
    end

    def skipped_email_change_for(person, incoming_email)
      return unless protected_email?(person)
      return if person.email == incoming_email.to_s.strip.downcase.presence

      {
        person_name: person.name,
        current_email: person.email,
        skipped_email: incoming_email
      }
    end
end
