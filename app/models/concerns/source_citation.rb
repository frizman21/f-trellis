# A sighting: a recorded fact, the source it was seen in, the run that saw it,
# and how much confidence to place in the citation.
#
# The run is required, and that is what the four tables are now named for (#71).
# Before it, a citation said only "this page mentions this fact", so extracting
# the same page a second time updated one row rather than adding to it and the
# history of how often something had been observed was lost. With the run on the
# row, a second extraction is a second sighting.
#
# It is required rather than nullable so the name is true of every row. Facts a
# person records by hand are sightings too, and get a run of their own — see
# ExtractionRun.manual.
#
# The four models differ only in what they point at, so everything else lives
# here. Including it requires the model to declare its own owner and to name it,
# so uniqueness can be scoped to it.
module SourceCitation
  extend ActiveSupport::Concern

  CONFIDENCE_RANGE = (1..100).freeze

  included do
    belongs_to :source
    belongs_to :extraction_run

    validates :confidence, presence: true,
                           inclusion: { in: CONFIDENCE_RANGE,
                                        message: "must be between 1 and 100" }
  end

  class_methods do
    # `owner` names the association a citation hangs off. Uniqueness is scoped to
    # it *and* to the run: one citation of a page per fact per run. A run that
    # mentions the same fact twice still saw it once; two runs saw it twice.
    def cites(owner)
      belongs_to owner
      validates :source_id, uniqueness: { scope: [ :"#{owner}_id", :extraction_run_id ] }
    end
  end
end
