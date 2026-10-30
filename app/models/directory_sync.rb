class DirectorySync
  def initialize(workspace, source)
    @workspace = workspace
    @source = source
  end

  def call
    counts = { created: 0, updated: 0, unchanged: 0 }

    workspace.transaction do
      source.each_person do |attributes|
        person = find_person(attributes)
        new_record = person.new_record?
        person.assign_attributes(
          name: attributes.fetch(:name),
          email: attributes.fetch(:email),
          phone: attributes.fetch(:phone),
          external_source: "planning_center",
          external_id: attributes.fetch(:external_id)
        )

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
    attr_reader :workspace, :source

    def find_person(attributes)
      workspace.people.find_by(
        external_source: "planning_center",
        external_id: attributes.fetch(:external_id)
      ) || adoptable_person(attributes) || workspace.people.build
    end

    def adoptable_person(attributes)
      email = attributes.fetch(:email)
      workspace.people.find_by(email:, external_id: nil) if email.present?
    end
end
