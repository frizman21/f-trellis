class ScienceTechnologyDetailsController < ApplicationController
  def show
    @detail = ScienceTechnologyDetail.find(params[:id])
    @edge   = @detail.science_technology
    @science  = @edge.science
    @technology = @edge.technology
    @is_current = @edge.current_detail_id == @detail.id
  end
end
