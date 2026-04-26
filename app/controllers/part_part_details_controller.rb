class PartPartDetailsController < ApplicationController
  def show
    @detail = PartPartDetail.find(params[:id])
    @edge   = @detail.part_part
    @part_a = @edge.part_a
    @part_b = @edge.part_b
    @is_current = @edge.current_detail_id == @detail.id
  end
end
