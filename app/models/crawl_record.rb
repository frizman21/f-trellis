class CrawlRecord < ApplicationRecord
  validates :url, presence: true
end
