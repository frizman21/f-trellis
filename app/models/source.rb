class Source < ApplicationRecord
  has_many :source_data, dependent: :destroy
  has_many :source_processing_reports, dependent: :destroy
end
