class MentionParser
  TOKEN_PATTERN = /@\[[^\]\r\n]*\]\(person:(\d+)\)/

  def initialize(mentionable)
    @mentionable = mentionable
  end

  def call
    visible_people = mentioned_people.select { |person| Policy.can?(person, :show, project) }
    visible_person_ids = visible_people.map(&:id)

    Mention.transaction do
      mentionable.mentions.where.not(person_id: visible_person_ids).destroy_all
      visible_people.each do |person|
        mentionable.mentions.create_or_find_by!(person:)
        followable.follows.create_or_find_by!(person:)
      end
    end
  end

  private
    attr_reader :mentionable

    def mentioned_people
      project.organization.people.where(id: mentioned_person_ids)
    end

    def mentioned_person_ids
      mentionable.body.to_plain_text.scan(TOKEN_PATTERN).flatten.map(&:to_i).uniq
    end

    def project
      mentionable.project
    end

    def followable
      return mentionable.commentable if mentionable.is_a?(Comment)

      mentionable.parent || mentionable
    end
end
