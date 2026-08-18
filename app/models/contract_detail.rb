class ContractDetail < ApplicationRecord
  belongs_to :contract
  belongs_to :source_processing_report
  has_many :contract_detail_contract_types, dependent: :destroy
  has_many :contract_types, through: :contract_detail_contract_types

  validates :identifier, presence: true

  # The contract's term, where both ends are known. Nil rather than a
  # half-open range: a start with no end is an open contract, not an error,
  # and the show page says so in words instead.
  def term
    return nil unless start_date && end_date

    start_date..end_date
  end

  def label
    title.presence ? "#{identifier} — #{title}" : identifier
  end
end
