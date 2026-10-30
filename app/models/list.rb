class List < ApplicationRecord
  belongs_to :project

  has_many :columns,
    -> { order(:position, :id) },
    class_name: "ListColumn",
    dependent: :destroy,
    inverse_of: :list
  has_many :rows,
    -> { order(:position, :id) },
    class_name: "ListRow",
    dependent: :destroy,
    inverse_of: :list

  validates :name, presence: true
end
