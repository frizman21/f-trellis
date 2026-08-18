# A citation: the source a recorded fact came from, and how much confidence to
# place in that citation.
#
# The four citation models differ only in what they point at, so everything else
# lives here. Including it requires the model to declare its own owner and to
# name it, so uniqueness can be scoped to it.
module SourceCitation
  extend ActiveSupport::Concern

  CONFIDENCE_RANGE = (1..100).freeze

  included do
    belongs_to :source

    validates :confidence, presence: true,
                           inclusion: { in: CONFIDENCE_RANGE,
                                        message: "must be between 1 and 100" }
  end

  class_methods do
    # `owner` names the association a citation hangs off, which is also what the
    # source must be unique within: one citation of a page per fact.
    def cites(owner)
      belongs_to owner
      validates :source_id, uniqueness: { scope: :"#{owner}_id" }
    end
  end
end
