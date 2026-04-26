require "zip"
require "stringio"

class SourceDatum < ApplicationRecord
  belongs_to :source

  def html
    return nil if data.blank?

    Zip::InputStream.open(StringIO.new(data)) do |io|
      entry = io.get_next_entry
      return nil unless entry
      io.read
    end
  end
end
