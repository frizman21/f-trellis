class PartPartDetailPartPartType < ApplicationRecord
  belongs_to :part_part_detail
  belongs_to :part_part_type
end
