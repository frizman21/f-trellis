class PersonSciencesController < ApplicationController
  def show
    @person_science = PersonScience.find(params[:id])
    @person = @person_science.person
    @science = @person_science.science
    @current = @person_science.current_detail
    @details = @person_science.person_science_details
                 .includes(:person_science_types, source_processing_report: :source)
                 .order(as_of: :desc, created_at: :desc)
  end
end
