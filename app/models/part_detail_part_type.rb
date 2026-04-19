class PartDetailPartType < ApplicationRecord
  belongs_to :part_detail
  belongs_to :part_type
end
