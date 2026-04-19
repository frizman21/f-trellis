class PartPart < ApplicationRecord
  belongs_to :part_a, class_name: "Part"
  belongs_to :part_b, class_name: "Part"
  belongs_to :current_detail, class_name: "PartPartDetail", optional: true
  has_many :part_part_details, dependent: :destroy

  def other_part(part)
    part_a_id == part.id ? part_b : part_a
  end
end
