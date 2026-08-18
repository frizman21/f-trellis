class Part < ApplicationRecord
  has_many :part_details, dependent: :destroy
  has_many :part_organizations, dependent: :destroy
  has_many :organizations, through: :part_organizations

  has_many :part_technologies, dependent: :destroy
  has_many :technologies, through: :part_technologies

  has_many :part_parts_as_a, class_name: "PartPart", foreign_key: :part_a_id, dependent: :destroy, inverse_of: :part_a
  has_many :part_parts_as_b, class_name: "PartPart", foreign_key: :part_b_id, dependent: :destroy, inverse_of: :part_b

  belongs_to :current_detail, class_name: "PartDetail", optional: true

  def part_parts
    PartPart.where("part_a_id = :id OR part_b_id = :id", id: id)
  end
end
