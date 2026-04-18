class Source < ApplicationRecord
  has_many :source_data, dependent: :destroy
end
