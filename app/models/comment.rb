class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
  belongs_to :author, class_name: "Person"
  has_many :mentions, as: :mentionable, dependent: :destroy

  has_rich_text :body

  validates :body, presence: true

  after_create :follow_author
  after_save :parse_mentions

  delegate :project, to: :commentable

  private
    def follow_author
      commentable.follows.create_or_find_by!(person: author)
    end

    def parse_mentions
      MentionParser.new(self).call
    end
end
