class PartTechnologiesController < ApplicationController
  def show
    @part_technology = PartTechnology.find(params[:id])
    @part = @part_technology.part
    @technology = @part_technology.technology
    @current = @part_technology.current_detail
    @details = @part_technology.part_technology_details
                 .includes(:part_technology_types, source_processing_report: :source)
                 .order(as_of: :desc, created_at: :desc)
  end
end
