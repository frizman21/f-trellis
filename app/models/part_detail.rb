class PartDetail < ApplicationRecord
  belongs_to :part
  belongs_to :source_processing_report
  has_many :part_detail_part_types, dependent: :destroy
  has_many :part_types, through: :part_detail_part_types
  # The measured values this detail asserts. Ordered by parameter name so a
  # specification table reads the same way every time.
  has_many :part_detail_parameters, -> { ordered }, dependent: :destroy, inverse_of: :part_detail

  validates :name, presence: true

  # Every parameter the part's types declare — what this detail *could* state,
  # against what it does. A part carrying two types is measured by both sets.
  def available_parameters
    PartTypeParameter.where(part_type_id: part_types.map(&:id)).ordered
  end
end
