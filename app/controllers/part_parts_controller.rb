class PartPartsController < ApplicationController
  def show
    @part_part = PartPart.find(params[:id])
    @part_a   = @part_part.part_a
    @part_b   = @part_part.part_b
    @current  = @part_part.current_detail
    @prior    = @part_part.part_part_details
                  .where.not(id: @current&.id)
                  .order(as_of: :desc)
  end
end
