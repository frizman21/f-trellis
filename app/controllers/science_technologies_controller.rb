class ScienceTechnologiesController < ApplicationController
  def show
    @science_technology = ScienceTechnology.find(params[:id])
    @science = @science_technology.science
    @technology = @science_technology.technology
    @current = @science_technology.current_detail
    @details = @science_technology.science_technology_details
                 .includes(:science_technology_types, source_processing_report: :source)
                 .order(as_of: :desc, created_at: :desc)
  end
end
