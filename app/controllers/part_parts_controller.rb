class PartPartsController < ApplicationController
  def show
    @part_part = PartPart.find(params[:id])
    @part_a   = @part_part.part_a
    @part_b   = @part_part.part_b
    @current  = @part_part.current_detail
    @details  = @part_part.part_part_details
                  .includes(:part_part_types, source_processing_report: :source)
                  .order(as_of: :desc, created_at: :desc)
  end
end
