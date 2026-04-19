class Source < ApplicationRecord
  STATUSES = %w[new in_work complete failed].freeze

  has_many :source_data, dependent: :destroy
  has_many :source_processing_reports, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
end
