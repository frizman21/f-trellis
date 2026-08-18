class PartTechnologyDetailsController < ApplicationController
  def show
    @detail = PartTechnologyDetail.find(params[:id])
    @edge   = @detail.part_technology
    @part  = @edge.part
    @technology = @edge.technology
    @is_current = @edge.current_detail_id == @detail.id
  end
end
