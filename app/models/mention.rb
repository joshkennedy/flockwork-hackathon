class Mention < ApplicationRecord
  belongs_to :mentionable, polymorphic: true
  belongs_to :person
end
